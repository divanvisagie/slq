use anyhow::Result;
use clap::{Parser, Subcommand};
use time::{Duration, OffsetDateTime, PrimitiveDateTime, UtcOffset, format_description};

use crate::client::{
    Departure, Site, get_departures, get_site_transport_modes, get_sites, search_for_sites,
    site_has_transport_mode,
};
use crate::types::TransportMode;

mod client;
mod types;

/// Storstockholms Lokaltrafik Query Tool
#[derive(Parser)]
#[command(version, about, long_about = None)]
struct Args {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Search for stations by name. Returns tab-delimited output with station names and IDs, suitable for shell scripting.
    Search {
        /// Station name
        station_name: String,
    },
    Departures {
        /// Station name or identifier
        station_name: String,
        /// Filter by line number. Base line numbers (e.g., "28") will include variants like
        /// "28s"). Specific variants can be filtered with exact matches, sho if you search for
        /// "28s" you will only get that result
        #[arg(short, long)]
        line: Option<String>,

        /// Maximum number of departures to show
        #[arg(short, long)]
        count: Option<usize>,

        /// Filter results by their destination
        #[arg(short, long)]
        destination: Option<String>,

        /// Filter by transport type
        #[arg(short, long)]
        transport_mode: Option<TransportMode>,
    },
    Closest {
        /// Latitude in decimal degrees
        lat: f64,

        /// Longitude in decimal degrees
        lon: f64,

        /// Maximum number of stations to return
        #[arg(short, long, default_value_t = 3)]
        limit: usize,

        /// Filter stations to those with departures for this transport mode
        #[arg(short = 't', long = "transport-mode", alias = "type")]
        transport_mode: Option<TransportMode>,
    },
}

fn string_to_date(expected: &str) -> Result<PrimitiveDateTime> {
    let fmt = format_description::parse("[year]-[month]-[day]T[hour]:[minute]:[second]")
        .expect("static format description");
    Ok(PrimitiveDateTime::parse(expected, &fmt)?)
}

/// Parse "2025-11-02T11:14:02" (no timezone) as local time and return a human wait string.
pub fn wait_time(expected: &str) -> String {
    let arrival = string_to_date(expected);
    match arrival {
        Ok(arrival) => {
            let now = OffsetDateTime::now_local().unwrap_or_else(|_| OffsetDateTime::now_utc());
            let local_off = UtcOffset::current_local_offset().unwrap_or(UtcOffset::UTC);
            let arrival: OffsetDateTime = arrival.assume_offset(local_off);
            let delta: Duration = arrival - now;

            if delta.is_negative() {
                return "now".into();
            }

            human(delta)
        }
        Err(_) => "unknown".to_string(),
    }
}

fn human(d: Duration) -> String {
    let s = d.whole_seconds();
    let h = s / 3600;
    let m = (s % 3600) / 60;
    let sec = s % 60;

    match (h, m, sec) {
        (0, 0, sec) => format!("{sec}s"),
        (0, m, _) => format!("{m}m"),
        (h, m, _) => format!("{h}h {m}m"),
    }
}

fn print_departure(departure: &Departure) {
    let wait = wait_time(&departure.expected.as_str());
    let pd = string_to_date(departure.expected.as_str())
        .expect("Could not parse date returned from API");
    let time = format_time(&pd);
    println!(
        "{}\t{}\t{}\t{:?}\t{}",
        wait,
        time,
        departure.line.designation,
        departure.line.transport_mode,
        departure.destination
    );
}

fn print_site(site: &Site) {
    println!("{}\t{}", site.name, site.id)
}

const EARTH_RADIUS_METERS: f64 = 6_371_000.0;
const MAX_MODE_FILTER_PROBES: usize = 200;
const DISTANCE_COL_WIDTH: usize = 10;
const STATION_COL_WIDTH: usize = 34;
const TYPE_COL_WIDTH: usize = 20;

#[derive(Clone)]
struct RankedSite {
    site: Site,
    distance_meters: f64,
}

fn haversine_meters(lat1: f64, lon1: f64, lat2: f64, lon2: f64) -> f64 {
    let d_lat = (lat2 - lat1).to_radians();
    let d_lon = (lon2 - lon1).to_radians();
    let a = (d_lat / 2.0).sin().powi(2)
        + lat1.to_radians().cos() * lat2.to_radians().cos() * (d_lon / 2.0).sin().powi(2);
    let c = 2.0 * a.sqrt().atan2((1.0 - a).sqrt());
    EARTH_RADIUS_METERS * c
}

fn rank_sites_by_distance(sites: &[Site], lat: f64, lon: f64) -> Vec<RankedSite> {
    let mut ranked: Vec<RankedSite> = sites
        .iter()
        .filter_map(|site| {
            let site_lat = site.lat?;
            let site_lon = site.lon?;
            Some(RankedSite {
                site: site.clone(),
                distance_meters: haversine_meters(lat, lon, site_lat, site_lon),
            })
        })
        .collect();

    ranked.sort_by(|a, b| {
        a.distance_meters
            .total_cmp(&b.distance_meters)
            .then_with(|| a.site.id.cmp(&b.site.id))
    });

    ranked
}

fn print_closest_site(ranked_site: &RankedSite) {
    let distance = format!("{:.0}m", ranked_site.distance_meters);
    println!(
        "{:<DISTANCE_COL_WIDTH$}{:<STATION_COL_WIDTH$}{}",
        distance, ranked_site.site.name, ranked_site.site.id
    );
}

fn transport_mode_rank(mode: TransportMode) -> u8 {
    match mode {
        TransportMode::Bus => 0,
        TransportMode::Tram => 1,
        TransportMode::Metro => 2,
        TransportMode::Train => 3,
        TransportMode::Ferry => 4,
        TransportMode::Ship => 5,
        TransportMode::Taxi => 6,
    }
}

fn transport_mode_label(mode: TransportMode) -> &'static str {
    match mode {
        TransportMode::Bus => "bus",
        TransportMode::Tram => "tram",
        TransportMode::Metro => "metro",
        TransportMode::Train => "train",
        TransportMode::Ferry => "ferry",
        TransportMode::Ship => "ship",
        TransportMode::Taxi => "taxi",
    }
}

fn closest_site_type_label(site_id: u32) -> String {
    match get_site_transport_modes(site_id, 20) {
        Ok(mut modes) if !modes.is_empty() => {
            modes.sort_by_key(|mode| transport_mode_rank(*mode));
            modes
                .iter()
                .map(|mode| transport_mode_label(*mode))
                .collect::<Vec<_>>()
                .join("/")
        }
        _ => "unknown".to_string(),
    }
}

fn print_closest_site_with_type(ranked_site: &RankedSite) {
    let distance = format!("{:.0}m", ranked_site.distance_meters);
    println!(
        "{:<DISTANCE_COL_WIDTH$}{:<STATION_COL_WIDTH$}{:<TYPE_COL_WIDTH$}{}",
        distance,
        ranked_site.site.name,
        closest_site_type_label(ranked_site.site.id),
        ranked_site.site.id
    );
}

fn print_closest_header(with_type: bool) {
    if with_type {
        println!(
            "{:<DISTANCE_COL_WIDTH$}{:<STATION_COL_WIDTH$}{:<TYPE_COL_WIDTH$}ID",
            "Distance", "Station", "Type"
        );
    } else {
        println!(
            "{:<DISTANCE_COL_WIDTH$}{:<STATION_COL_WIDTH$}ID",
            "Distance", "Station"
        );
    }
}

fn format_time(date: &PrimitiveDateTime) -> String {
    format!("{:02}:{:02}", date.hour(), date.minute())
}

fn main() -> Result<()> {
    let args = Args::parse();

    match &args.command {
        Commands::Search { station_name } => {
            let sites = search_for_sites(station_name.as_str())?;
            sites.iter().for_each(|s| print_site(s));
        }
        Commands::Departures {
            station_name,
            line,
            count,
            transport_mode,
            destination,
        } => {
            let (site_id, site_name) = if station_name.parse::<u64>().is_ok() {
                (station_name.clone(), station_name.clone())
            } else {
                let sites = search_for_sites(station_name.as_str())?;
                if let Some(site) = sites.get(0) {
                    (site.id.to_string(), site.name.clone())
                } else {
                    println!("Error: Station '{}' not found.", station_name);
                    return Ok(());
                }
            };

            println!("Departures from {}:", site_name);
            let departures = get_departures(&site_id, line, count, transport_mode, destination)?;
            departures.iter().for_each(|d| print_departure(d));
        }
        Commands::Closest {
            lat,
            lon,
            limit,
            transport_mode,
        } => {
            let ranked_sites = rank_sites_by_distance(&get_sites()?, *lat, *lon);
            if ranked_sites.is_empty() {
                println!("Error: No stations with coordinates found.");
                return Ok(());
            }

            if let Some(mode) = transport_mode {
                let mut filtered_results: Vec<RankedSite> = Vec::new();
                print_closest_header(false);
                for ranked_site in ranked_sites.iter().take(MAX_MODE_FILTER_PROBES) {
                    if filtered_results.len() >= *limit {
                        break;
                    }

                    if site_has_transport_mode(ranked_site.site.id, *mode)? {
                        filtered_results.push(ranked_site.clone());
                    }
                }
                filtered_results.iter().for_each(print_closest_site);
            } else {
                print_closest_header(true);
                ranked_sites
                    .iter()
                    .take(*limit)
                    .for_each(print_closest_site_with_type);
            }
        }
    };
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn site(id: u32, name: &str, lat: f64, lon: f64) -> Site {
        Site {
            id,
            name: name.to_string(),
            lat: Some(lat),
            lon: Some(lon),
        }
    }

    #[test]
    fn haversine_is_zero_for_identical_points() {
        let distance = haversine_meters(59.331, 18.06, 59.331, 18.06);
        assert!(distance < 0.001);
    }

    #[test]
    fn rank_sites_orders_by_distance_then_id() {
        let sites = vec![
            site(10, "Far", 59.40, 18.30),
            site(2, "Near B", 59.331, 18.060),
            site(1, "Near A", 59.331, 18.060),
        ];

        let ranked = rank_sites_by_distance(&sites, 59.331, 18.060);

        assert_eq!(ranked[0].site.id, 1);
        assert_eq!(ranked[1].site.id, 2);
        assert_eq!(ranked[2].site.id, 10);
    }
}

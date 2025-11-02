use anyhow::Result;
use clap::{Parser, Subcommand};
use time::{Duration, OffsetDateTime, PrimitiveDateTime, UtcOffset, format_description};

use crate::client::{Departure, Site, TransportMode, get_departures, search_for_sites};

mod client;

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

        /// Filter by transport type
        #[arg(short, long)]
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
        "{}\t{}\t{}\t{}\t{:?}",
        wait,
        time,
        departure.line.designation,
        departure.destination,
        departure.line.transport_mode
    );
}

fn print_site(site: &Site) {
    println!("{}\t{}", site.name, site.id)
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
            let departures = get_departures(&site_id, line, count, transport_mode)?;
            departures.iter().for_each(|d| print_departure(d));
        }
    };
    Ok(())
}

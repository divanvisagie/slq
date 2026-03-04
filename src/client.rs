use anyhow::{Context, Result};
use deunicode::deunicode;
use reqwest::blocking::Client;
use serde::Deserialize;

use crate::types::TransportMode;

const BUNDLED_SITES_JSON: &str = include_str!("../data/sites.json");

#[derive(Deserialize, Clone, Debug)]
pub struct Site {
    pub id: u32,
    pub name: String,
    pub lat: Option<f64>,
    pub lon: Option<f64>,
}

#[derive(Deserialize, Clone)]
pub struct Line {
    pub designation: String,
    pub transport_mode: TransportMode,
}

/// Represents The response that comes back for the destination
/// for a single trip
#[derive(Deserialize, Clone)]
pub struct Departure {
    pub destination: String,
    pub expected: String,
    pub line: Line,
}

#[derive(Deserialize, Clone)]
struct DestinationHttpResult {
    /// List of destinations
    departures: Vec<Departure>,
}

pub fn get_departures(
    station_name_or_id: &str,
    line: &Option<String>,
    count: &Option<usize>,
    transport_mode: &Option<TransportMode>,
    destination: &Option<String>,
) -> Result<Vec<Departure>> {
    let url = format!(
        "https://transport.integration.sl.se/v1/sites/{}/departures",
        station_name_or_id
    );

    let client = Client::new();
    let res = client.get(&url).send()?;

    let api_response = res.json::<DestinationHttpResult>()?;
    let departures = api_response.departures;

    let departures = match line {
        Some(l) => departures
            .iter()
            .filter(|d| d.line.designation.starts_with(l))
            .cloned()
            .collect(),
        None => departures,
    };

    let departures = match transport_mode {
        Some(l) => departures
            .iter()
            .filter(|d| d.line.transport_mode == *l)
            .cloned()
            .collect(),
        None => departures,
    };

    let departures = match destination {
        Some(dest) => {
            let query = deunicode(dest).to_lowercase();
            departures
                .iter()
                .filter(|d| {
                    deunicode(d.destination.as_str())
                        .to_lowercase()
                        .contains(&query)
                })
                .cloned()
                .collect()
        }
        None => departures,
    };

    match count {
        Some(limit) => {
            let limited = departures.iter().cloned().take(*limit).collect();
            Ok(limited)
        }
        None => Ok(departures),
    }
}

pub fn get_sites() -> Result<Vec<Site>> {
    let snapshot_sites: Vec<Site> = serde_json::from_str(BUNDLED_SITES_JSON)
        .context("failed to parse bundled station snapshot (data/sites.json)")?;
    if !snapshot_sites.is_empty() {
        return Ok(snapshot_sites);
    }

    let url = "https://transport.integration.sl.se/v1/sites";
    let client = Client::new();

    let res = client.get(url).send()?;
    let api_response = res.json::<Vec<Site>>()?;

    Ok(api_response)
}

pub fn site_has_transport_mode(site_id: u32, transport_mode: TransportMode) -> Result<bool> {
    let site_id = site_id.to_string();
    let count = Some(1usize);
    let mode = Some(transport_mode);
    let departures = get_departures(&site_id, &None, &count, &mode, &None)?;
    Ok(!departures.is_empty())
}

pub fn get_site_transport_modes(site_id: u32, sample_size: usize) -> Result<Vec<TransportMode>> {
    let site_id = site_id.to_string();
    let count = Some(sample_size);
    let departures = get_departures(&site_id, &None, &count, &None, &None)?;

    let mut modes: Vec<TransportMode> = Vec::new();
    for departure in departures {
        let mode = departure.line.transport_mode;
        if !modes.contains(&mode) {
            modes.push(mode);
        }
    }

    Ok(modes)
}

pub fn search_for_sites(query: &str) -> Result<Vec<Site>> {
    let sites = get_sites()?;
    let query = deunicode(query).to_lowercase(); //Ignore accents on ö å ä
    let sites = sites
        .iter()
        .filter(|s| deunicode(s.name.as_str()).to_lowercase().contains(&query))
        .cloned()
        .collect();
    Ok(sites)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn get_departures_should_obey_line_limit() {
        let departures = get_departures("9600", &None, &Some(2), &None, &None);
        let actual = departures.unwrap().len();
        assert_eq!(2, actual);

        let departures = get_departures("9600", &None, &Some(1), &None, &None);
        let actual = departures.unwrap().len();
        assert_eq!(1, actual);
    }

    #[test]
    fn get_departures_should_filter_lines() -> Result<()> {
        let departures = get_departures("9600", &Some("28".to_string()), &Some(1), &None, &None)?;
        if !departures
            .iter()
            .all(|d| d.line.designation.starts_with("28"))
        {
            assert!(false, "Should only contain results for line 28");
        }
        Ok(())
    }

    #[test]
    fn test_get_sites() -> Result<()> {
        let sites = get_sites()?;
        let count = sites.iter().count();
        assert_ne!(0, count);
        Ok(())
    }
}

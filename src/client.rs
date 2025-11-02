use anyhow::Result;
use clap::ValueEnum;
use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, ValueEnum)]
#[serde(rename_all = "UPPERCASE")]
pub enum TransportMode {
    Bus,
    Tram,
    Metro,
    Train,
    Ferry,
    Ship,
    Taxi,
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

    match count {
        Some(limit) => {
            let limited = departures.iter().cloned().take(*limit).collect();
            Ok(limited)
        }
        None => Ok(departures),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn get_departures_should_obey_line_limit() {
        let departures = get_departures("9600", &None, &Some(2), &None);
        let actual = departures.unwrap().len();
        assert_eq!(2, actual);

        let departures = get_departures("9600", &None, &Some(1), &None);
        let actual = departures.unwrap().len();
        assert_eq!(1, actual);
    }

    #[test]
    fn get_departures_should_filter_lines() -> Result<()> {
        let departures = get_departures("9600", &Some("28".to_string()), &Some(1), &None)?;
        if !departures
            .iter()
            .all(|d| d.line.designation.starts_with("28"))
        {
            assert!(false, "Should only contain results for line 28");
        }
        Ok(())
    }
}

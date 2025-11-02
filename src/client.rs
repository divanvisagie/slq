use anyhow::Result;
use reqwest::blocking::Client;
use serde::Deserialize;

// struct Departure {
//     wait: u32,
//     time: String,
//     line: String,
//     destination: String,
//     transport_type: String,
// }

#[derive(Deserialize, Clone)]
struct StopArea {
    id: u32,
    name: String,
    r#type: String,
}

#[derive(Deserialize, Clone)]
pub struct Line {
    id: u32,
    pub designation: String,
    transport_mode: String,
}

/// Represents The response that comes back for the destination
/// for a single trip
#[derive(Deserialize, Clone)]
pub struct Departure {
    /// Where the trip is going
    pub destination: String,
    pub state: String,
    pub expected: String,
    pub stop_area: StopArea,
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
        let departures = get_departures("9600".to_string(), None, Some(2));
        let actual = departures.unwrap().len();
        assert_eq!(2, actual);

        let departures = get_departures("9600".to_string(), None, Some(1));
        let actual = departures.unwrap().len();
        assert_eq!(1, actual);
    }

    #[test]
    fn get_departures_should_filter_lines() -> Result<()> {
        let departures = get_departures("9600".to_string(), Some("28".to_string()), Some(1))?;
        if !departures
            .iter()
            .all(|d| d.line.designation.starts_with("28"))
        {
            assert!(false, "Should only contain results for line 28");
        }
        Ok(())
    }
}

use chrono::{TimeZone, Utc};
use reqwest::blocking::Client;
use serde::Deserialize;
use std::error::Error;

#[derive(Debug, Deserialize)]
pub struct StopInfo {
    pub name: String,
    pub id: u32,
}

#[derive(Debug, Deserialize)]
struct SiteInfo {
    id: u32,
    name: String,
}

#[derive(Debug, Deserialize)]
struct DeparturesResponse {
    departures: Vec<Departure>,
}

#[derive(Debug, Deserialize)]
pub struct Departure {
    pub destination: String,
    pub expected: String,
    pub line: Line,
}

#[derive(Debug, Deserialize)]
pub struct Line {
    pub designation: String,
    pub group_of_lines: Option<String>,
}

pub struct SlClient {
    client: Client,
}

impl SlClient {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
        }
    }

    pub fn search_stops(&self, query: &str) -> Result<Vec<StopInfo>, Box<dyn Error>> {
        let url = "https://transport.integration.sl.se/v1/sites?expand=true";
        let sites: Vec<SiteInfo> = self.client.get(url).send()?.json()?;

        let query_lower = query.to_lowercase();
        let filtered_sites: Vec<StopInfo> = sites
            .into_iter()
            .filter(|site| site.name.to_lowercase().contains(&query_lower))
            .map(|site| StopInfo {
                name: site.name,
                id: site.id,
            })
            .collect();

        Ok(filtered_sites)
    }

    fn get_sites(&self) -> Result<Vec<SiteInfo>, Box<dyn Error>> {
        let url = "https://transport.integration.sl.se/v1/sites?expand=true";
        let sites: Vec<SiteInfo> = self.client.get(url).send()?.json()?;
        Ok(sites)
    }

    pub fn get_departures(
        &self,
        station: &str,
        line_filter: Option<&str>,
        transport_filter: Option<&str>,
        destination_filter: Option<&str>,
    ) -> Result<Vec<Departure>, Box<dyn Error>> {
        let site_id = if let Ok(id) = station.parse::<u32>() {
            id
        } else {
            let sites = self.get_sites()?;
            sites
                .iter()
                .find(|site| site.name.to_lowercase().contains(&station.to_lowercase()))
                .ok_or(format!("No site found for '{}'", station))?
                .id
        };

        let url = format!(
            "https://transport.integration.sl.se/v1/sites/{}/departures",
            site_id
        );

        let response: DeparturesResponse = self.client.get(&url).send()?.json()?;

        let mut departures = response.departures;

        departures.retain(|d| d.line.group_of_lines.is_some());

        if let Some(line) = line_filter {
            departures.retain(|d| {
                let designation = &d.line.designation;
                // Exact match first
                if designation.eq_ignore_ascii_case(line) {
                    return true;
                }
                // Check if the designation starts with the line number (for variants like 28s, 28X)
                if designation.to_lowercase().starts_with(&line.to_lowercase()) {
                    // Make sure it's followed by a letter (not another digit)
                    if let Some(next_char) = designation.chars().nth(line.len()) {
                        return next_char.is_alphabetic();
                    }
                }
                false
            });
        }

        // Apply transport type filter
        if let Some(transport) = transport_filter {
            departures.retain(|d| {
                let transport_lower = transport.to_lowercase();
                if let Some(group) = &d.line.group_of_lines {
                    let group_lower = group.to_lowercase();
                    match transport_lower.as_str() {
                        "metro" => group_lower.contains("tunnelbanan"),
                        "bus" => {
                            group_lower.contains("buss") || group_lower.contains("närtrafiken")
                        }
                        "train" => {
                            group_lower.contains("pendeltåg")
                                || group_lower.contains("roslagsbanan")
                        }
                        "tram" => group_lower.contains("spårväg"),
                        _ => true, // Unknown filter, show all
                    }
                } else {
                    false // No group_of_lines, filter out
                }
            });
        }

        // Apply destination filter
        if let Some(destination) = destination_filter {
            departures.retain(|d| {
                // Check if destination filter is numeric (ID)
                if let Ok(dest_id) = destination.parse::<u32>() {
                    // For ID matching, we'd need to resolve destination names to IDs
                    // For now, just check if the destination contains the ID as string
                    d.destination.contains(&dest_id.to_string())
                } else {
                    // Name-based filtering (case-insensitive partial match)
                    d.destination
                        .to_lowercase()
                        .contains(&destination.to_lowercase())
                }
            });
        }

        Ok(departures)
    }

    /// Parse departure time from string in local datetime format (2025-09-09T13:33:30) and extract time in HH:MM format
    pub fn parse_departure_time(&self, time_str: &str) -> Option<String> {
        if let Ok(naive_dt) = chrono::NaiveDateTime::parse_from_str(time_str, "%Y-%m-%dT%H:%M:%S") {
            Some(naive_dt.format("%H:%M").to_string())
        } else {
            None
        }
    }

    pub fn calculate_wait_minutes(&self, time_str: &str) -> Option<i64> {
        if let Ok(naive_dt) = chrono::NaiveDateTime::parse_from_str(time_str, "%Y-%m-%dT%H:%M:%S") {
            // Assume Stockholm timezone for the departure time
            let stockholm_tz = chrono_tz::Europe::Stockholm;
            if let Some(stockholm_dt) = stockholm_tz.from_local_datetime(&naive_dt).single() {
                let now = Utc::now();
                let diff = stockholm_dt.with_timezone(&Utc) - now;
                Some(diff.num_minutes().max(0)) // Don't show negative wait times
            } else {
                None
            }
        } else {
            None
        }
    }
}

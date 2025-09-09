mod cli;
mod client;

use clap::Parser;
use std::error::Error;

use cli::{Cli, Commands};
use client::SlClient;

fn handle_search(client: &SlClient, query: &str) -> Result<(), Box<dyn Error>> {
    let stops = client.search_stops(query)?;
    for stop in stops {
        println!("{}\t{}", stop.name, stop.id);
    }
    Ok(())
}

fn handle_departures(
    client: &SlClient,
    station: &str,
    line: Option<&str>,
    transport_type: Option<&str>,
    count: usize,
    destination: Option<&str>,
) -> Result<(), Box<dyn Error>> {
    let departures = client.get_departures(station, line, transport_type, destination)?;

    if departures.is_empty() {
        println!("No departures found");
        return Ok(());
    }

    let mut title = format!("Departures from {}", station);
    if let Some(line) = line {
        title.push_str(&format!(" (line {})", line));
    }
    if let Some(transport) = transport_type {
        title.push_str(&format!(" ({})", transport));
    }
    if let Some(dest) = destination {
        title.push_str(&format!(" (to {})", dest));
    }
    println!("{}:", title);
    println!(
        "{:<5} {:<6} {:<6} {:<20} Type",
        "Wait", "Time", "Line", "Destination"
    );
    println!("{}", "-".repeat(70));

    for departure in departures.iter().take(count) {
        let actual_time = client
            .parse_departure_time(&departure.expected)
            .unwrap_or_else(|| "??:??".to_string());

        let wait_minutes = client
            .calculate_wait_minutes(&departure.expected)
            .map(|m| {
                if m == 0 {
                    "Now".to_string()
                } else {
                    format!("{}m", m)
                }
            })
            .unwrap_or_else(|| "?".to_string());

        println!(
            "{:<5} {:<6} {:<6} {:<20} {}",
            wait_minutes,
            actual_time,
            departure.line.designation,
            departure.destination,
            departure
                .line
                .group_of_lines
                .as_deref()
                .unwrap_or("Unknown")
        );
    }
    Ok(())
}

fn main() -> Result<(), Box<dyn Error>> {
    let cli = Cli::parse();
    let client = SlClient::new();

    match cli.command {
        Commands::Search { query } => handle_search(&client, &query),
        Commands::Departures {
            station,
            line,
            transport_type,
            count,
            destination,
        } => handle_departures(
            &client,
            &station,
            line.as_deref(),
            transport_type.as_deref(),
            count,
            destination.as_deref(),
        ),
    }
}

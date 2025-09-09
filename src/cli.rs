use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "slq")]
#[command(about = "Query Storstockholms Lokaltrafik (SL)")]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Find station names and IDs
    Search {
        /// Search query for station names
        query: String,
    },
    /// Show upcoming departures for a site
    Departures {
        /// Station name or site ID
        station: String,
        /// Filter by line number (e.g., "14" or "28" includes variants like "28s")
        #[arg(short, long)]
        line: Option<String>,
        /// Filter by transport type (metro, bus, train, tram) - matches Swedish transport systems
        #[arg(short = 't', long)]
        transport_type: Option<String>,
        /// Number of departures to show (default: 10)
        #[arg(short = 'c', long, default_value = "10")]
        count: usize,
        /// Filter by destination name or ID
        #[arg(short = 'd', long)]
        destination: Option<String>,
    },
}

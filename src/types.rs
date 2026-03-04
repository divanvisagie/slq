use clap::ValueEnum;
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

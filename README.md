# slq - Storstockholms Lokaltrafik Query

A CLI tool for querying [Storstockholms Lokaltrafik (SL)](https://sl.se) information.

```
|[][SL][][] \
 oo---=--oo |
```

## Installation

**System-wide installation:**
```sh
cargo install slq
```

This will build the project and install `slq` using `cargo install`.

**Quick Demo:**
```sh
# Search for stations
$ slq search "taby centrum"
Täby centrum    9669

$ slq departures "T-Centralen" -t metro -l 14
Departures from T-Centralen:
1m      19:23   14      Metro   Mörby centrum
7m      19:29   14      Metro   Fruängen
11m     19:32   14      Metro   Mörby centrum
11m     19:33   14      Metro   Mörby centrum
17m     19:39   14      Metro   Fruängen
27m     19:49   14      Metro   Fruängen
```

## Usage

### Search for stations

Search for stations by name. Returns tab-delimited output with station names and IDs, suitable for shell scripting

Usage: `slq search <STATION_NAME>`

Arguments:
  <STATION_NAME>  Station name

Options:
  `-h`, `--help`  Print help

### Check departures
Usage: `slq departures [OPTIONS] <STATION_NAME>`

Arguments:
  <STATION_NAME>  Station name or identifier

Options:
  - `-l`, `--line <LINE>`
          Filter by line number. Base line numbers (e.g., "28") will include variants like "28s"). Specific variants can be filtered with exact matches, sho if you search for "28s" you will only get that result
  - `-c`, `--count <COUNT>`
          Maximum number of departures to show
  - `-d`, `--destination <DESTINATION>`
          Filter results by their destination
  - `-t`, `--transport-mode <TRANSPORT_MODE>`
          Filter by transport type possible values: `bus, tram, metro, train, ferry, ship, taxi`
  - `-h`, `--help`
          Print help

### Find closest stations by coordinate
Usage: `slq closest [OPTIONS] <LAT> <LON>`

Arguments:
  <LAT>  Latitude in decimal degrees
  <LON>  Longitude in decimal degrees

Options:
  - `-l`, `--limit <LIMIT>`
          Maximum number of stations to return (default: `3`)
  - `-t`, `--transport-mode <TRANSPORT_MODE>`
          Filter results to stations with departures for a transport type (alias: `--type`). Possible values: `bus, tram, metro, train, ferry, ship, taxi`
  - `-h`, `--help`
          Print help

Example:
```sh
slq closest 59.3313 18.0604
slq closest 59.3313 18.0604 --transport-mode metro --limit 2
slq closest 59.3313 18.0604 --type metro --limit 2
```

Output notes:
- Unfiltered `closest` output includes inferred transport type(s) from live departures.
- Filtered `closest --transport-mode/--type` keeps the compact output format (`distance`, `name`, `id`).

## Build and Data Snapshot

`make` now refreshes the bundled station snapshot from the SL sites API before building.

```sh
make                 # refresh data/sites.json, then build
make update-sites    # refresh snapshot only
make SKIP_SITE_REFRESH=1  # build without refreshing snapshot
```

## APIs Used

- **SL Transport API**: For station search and departure information
  - `https://transport.integration.sl.se/v1/sites` - Station directory
  - `https://transport.integration.sl.se/v1/sites/{id}/departures` - Real-time departures

No API key required for these endpoints.


## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](file:LICENSE) file for details.

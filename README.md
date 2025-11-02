# slq - Storstockholms Lokaltrafik Query

A CLI tool for querying [Storstockholms Lokaltrafik (SL)](https://sl.se) information.

```
|[][SL][][] \
 oo---=--oo |
```

## Installation

**System-wide installation:**
```sh
make install
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

Usage: slq search <STATION_NAME>

Arguments:
  <STATION_NAME>  Station name

Options:
  -h, --help  Print help

### Check departures
Usage: slq departures [OPTIONS] <STATION_NAME>

Arguments:
  <STATION_NAME>  Station name or identifier

Options:
  -l, --line <LINE>
          Filter by line number. Base line numbers (e.g., "28") will include variants like "28s"). Specific variants can be filtered with exact matches, sho if you search for "28s" you will only get that result
  -c, --count <COUNT>
          Maximum number of departures to show
  -d, --destination <DESTINATION>
          Filter results by their destination
  -t, --transport-mode <TRANSPORT_MODE>
          Filter by transport type [possible values: bus, tram, metro, train, ferry, ship, taxi]
  -h, --help
          Print help

## APIs Used

- **SL Transport API**: For station search and departure information
  - `https://transport.integration.sl.se/v1/sites` - Station directory
  - `https://transport.integration.sl.se/v1/sites/{id}/departures` - Real-time departures

No API key required for these endpoints.


## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](file:LICENSE) file for details.



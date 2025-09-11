#ifndef CLI_H
#define CLI_H

#include "types.h"

// Function to print usage/help information
void print_usage(const char *program_name);

// Function to print help for search command
void print_search_help(void);

// Function to print help for departures command
void print_departures_help(void);

// Function to parse command line arguments
int parse_args(int argc, char *argv[], CliArgs_t *args);

// Function to initialize CLI args structure with defaults
void init_cli_args(CliArgs_t *args);

// Function to validate parsed arguments
int validate_args(const CliArgs_t *args);

#endif // CLI_H
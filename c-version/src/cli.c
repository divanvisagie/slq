#include "cli.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>

// Print main usage information
void print_usage(const char *program_name) {
    printf("Usage: %s <command> [options]\n\n", program_name);
    printf("Query Storstockholms Lokaltrafik (SL)\n\n");
    printf("Commands:\n");
    printf("  search <query>              Find station names and IDs\n");
    printf("  departures <station>        Show upcoming departures for a station\n");
    printf("  help                        Show this help message\n\n");
    printf("For command-specific help, use: %s <command> --help\n", program_name);
}

// Print help for search command
void print_search_help(void) {
    printf("Usage: slq search <query>\n\n");
    printf("Find station names and IDs\n\n");
    printf("Arguments:\n");
    printf("  <query>    Search query for station names\n\n");
    printf("Examples:\n");
    printf("  slq search \"Central\"\n");
    printf("  slq search \"gamla\"\n\n");
    printf("Output format is tab-delimited: <name>\\t<id>\n");
}

// Print help for departures command
void print_departures_help(void) {
    printf("Usage: slq departures <station> [options]\n\n");
    printf("Show upcoming departures for a station\n\n");
    printf("Arguments:\n");
    printf("  <station>              Station name or site ID\n\n");
    printf("Options:\n");
    printf("  -l, --line <line>      Filter by line number (e.g., \"14\" or \"28\")\n");
    printf("  -t, --transport-type <type>\n");
    printf("                         Filter by transport type:\n");
    printf("                         metro (tunnelbanan), bus, train, tram\n");
    printf("  -c, --count <number>   Number of departures to show (default: 10)\n");
    printf("  -d, --destination <dest>\n");
    printf("                         Filter by destination name or ID\n");
    printf("  -h, --help             Show this help message\n\n");
    printf("Examples:\n");
    printf("  slq departures \"T-Centralen\"\n");
    printf("  slq departures \"9001\"\n");
    printf("  slq departures \"T-Centralen\" --line 14\n");
    printf("  slq departures \"T-Centralen\" --transport-type metro\n");
    printf("  slq departures \"Odenplan\" --destination \"Airport\"\n");
    printf("  slq departures \"T-Centralen\" --count 20\n");
}

// Initialize CLI args structure with defaults
void init_cli_args(cli_args_t *args) {
    if (!args) return;
    
    args->command = CMD_HELP;
    args->query = NULL;
    args->station = NULL;
    args->line = NULL;
    args->transport_type = NULL;
    args->destination = NULL;
    args->count = 10;
}

// Helper function to duplicate a string
static char *strdup_safe(const char *str) {
    if (!str) return NULL;
    
    size_t len = strlen(str) + 1;
    char *dup = malloc(len);
    if (dup) {
        memcpy(dup, str, len);
    }
    return dup;
}

// Parse command line arguments
int parse_args(int argc, char *argv[], cli_args_t *args) {
    if (!args || argc < 2) {
        return -1;
    }
    
    init_cli_args(args);
    
    // Parse main command
    if (strcmp(argv[1], "search") == 0) {
        args->command = CMD_SEARCH;
        
        if (argc < 3) {
            fprintf(stderr, "Error: search command requires a query argument\n");
            return -1;
        }
        
        args->query = strdup_safe(argv[2]);
        if (!args->query) {
            fprintf(stderr, "Error: memory allocation failed\n");
            return -1;
        }
        
        return 0;
    }
    else if (strcmp(argv[1], "departures") == 0) {
        args->command = CMD_DEPARTURES;
        
        if (argc < 3) {
            fprintf(stderr, "Error: departures command requires a station argument\n");
            return -1;
        }
        
        args->station = strdup_safe(argv[2]);
        if (!args->station) {
            fprintf(stderr, "Error: memory allocation failed\n");
            return -1;
        }
        
        // Parse departures options using getopt
        int opt;
        optind = 3; // Start parsing from the third argument
        
        struct option long_options[] = {
            {"line", required_argument, 0, 'l'},
            {"transport-type", required_argument, 0, 't'},
            {"count", required_argument, 0, 'c'},
            {"destination", required_argument, 0, 'd'},
            {"help", no_argument, 0, 'h'},
            {0, 0, 0, 0}
        };
        
        while ((opt = getopt_long(argc, argv, "l:t:c:d:h", long_options, NULL)) != -1) {
            switch (opt) {
                case 'l':
                    args->line = strdup_safe(optarg);
                    if (!args->line) {
                        fprintf(stderr, "Error: memory allocation failed\n");
                        return -1;
                    }
                    break;
                    
                case 't':
                    args->transport_type = strdup_safe(optarg);
                    if (!args->transport_type) {
                        fprintf(stderr, "Error: memory allocation failed\n");
                        return -1;
                    }
                    break;
                    
                case 'c':
                    args->count = atoi(optarg);
                    if (args->count <= 0) {
                        fprintf(stderr, "Error: count must be a positive number\n");
                        return -1;
                    }
                    break;
                    
                case 'd':
                    args->destination = strdup_safe(optarg);
                    if (!args->destination) {
                        fprintf(stderr, "Error: memory allocation failed\n");
                        return -1;
                    }
                    break;
                    
                case 'h':
                    print_departures_help();
                    return 1; // Special return code for help
                    
                case '?':
                default:
                    fprintf(stderr, "Error: unknown option\n");
                    return -1;
            }
        }
        
        return 0;
    }
    else if (strcmp(argv[1], "help") == 0 || strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
        args->command = CMD_HELP;
        print_usage("slq");
        return 1; // Special return code for help
    }
    else {
        fprintf(stderr, "Error: unknown command '%s'\n", argv[1]);
        return -1;
    }
}

// Validate parsed arguments
int validate_args(const cli_args_t *args) {
    if (!args) return -1;
    
    switch (args->command) {
        case CMD_SEARCH:
            if (!args->query) {
                fprintf(stderr, "Error: search query cannot be empty\n");
                return -1;
            }
            break;
            
        case CMD_DEPARTURES:
            if (!args->station || strlen(args->station) == 0) {
                fprintf(stderr, "Error: station cannot be empty\n");
                return -1;
            }
            
            if (args->count <= 0 || args->count > 100) {
                fprintf(stderr, "Error: count must be between 1 and 100\n");
                return -1;
            }
            
            // Validate transport type if provided
            if (args->transport_type) {
                const char *valid_types[] = {"metro", "bus", "train", "tram"};
                int valid = 0;
                for (size_t i = 0; i < sizeof(valid_types) / sizeof(valid_types[0]); i++) {
                    if (strcmp(args->transport_type, valid_types[i]) == 0) {
                        valid = 1;
                        break;
                    }
                }
                if (!valid) {
                    fprintf(stderr, "Error: invalid transport type '%s'. Valid types: metro, bus, train, tram\n", 
                            args->transport_type);
                    return -1;
                }
            }
            break;
            
        case CMD_HELP:
            // Help command is always valid
            break;
            
        default:
            fprintf(stderr, "Error: invalid command\n");
            return -1;
    }
    
    return 0;
}
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curl/curl.h>
#include "cli.h"
#include "client.h"
#include "types.h"

// Handle search command
int handle_search(SlClient_t *client, const char *query) {
    if (!client || !query) return -1;
    
    StopList_t *stops = NULL;
    if (sl_search_stops(client, query, &stops) != 0) {
        fprintf(stderr, "Failed to search for stops\n");
        return -1;
    }
    
    if (!stops || stops->count == 0) {
        free_stop_list(stops);
        return 0;
    }
    
    // Print results in tab-delimited format
    for (size_t i = 0; i < stops->count; i++) {
        printf("%s\t%u\n", stops->stops[i].name, stops->stops[i].id);
    }
    
    free_stop_list(stops);
    return 0;
}

// Handle departures command
int handle_departures(SlClient_t *client, const char *station,
                     const char *line, const char *transport_type,
                     int count, const char *destination) {
    if (!client || !station) return -1;
    
    DepartureList_t *departures = NULL;
    if (sl_get_departures(client, station, line, transport_type, destination, &departures) != 0) {
        fprintf(stderr, "Failed to get departures\n");
        return -1;
    }
    
    if (!departures || departures->count == 0) {
        printf("No departures found\n");
        free_departure_list(departures);
        return 0;
    }
    
    // Build title
    char title[256];
    snprintf(title, sizeof(title), "Departures from %s", station);
    
    if (line) {
        char temp[64];
        snprintf(temp, sizeof(temp), " (line %s)", line);
        strncat(title, temp, sizeof(title) - strlen(title) - 1);
    }
    
    if (transport_type) {
        char temp[64];
        snprintf(temp, sizeof(temp), " (%s)", transport_type);
        strncat(title, temp, sizeof(title) - strlen(title) - 1);
    }
    
    if (destination) {
        char temp[64];
        snprintf(temp, sizeof(temp), " (to %s)", destination);
        strncat(title, temp, sizeof(title) - strlen(title) - 1);
    }
    
    printf("%s:\n", title);
    printf("%-5s %-6s %-6s %-20s Type\n", "Wait", "Time", "Line", "Destination");
    printf("%s\n", "----------------------------------------------------------------------");
    
    // Print departures (limited by count)
    size_t max_count = (size_t)count;
    if (max_count > departures->count) {
        max_count = departures->count;
    }
    
    for (size_t i = 0; i < max_count; i++) {
        Departure_t *dep = &departures->departures[i];
        
        // Parse time
        char actual_time[16] = "??:??";
        parse_departure_time(dep->expected, actual_time, sizeof(actual_time));
        
        // Calculate wait time
        int wait_mins = calculate_wait_minutes(dep->expected);
        char wait_str[16];
        if (wait_mins == 0) {
            strcpy(wait_str, "Now");
        } else if (wait_mins < 0) {
            strcpy(wait_str, "?");
        } else {
            snprintf(wait_str, sizeof(wait_str), "%dm", wait_mins);
        }
        
        // Get transport type (group_of_lines)
        const char *type = dep->line.group_of_lines ? dep->line.group_of_lines : "Unknown";
        
        printf("%-5s %-6s %-6s %-20s %s\n",
               wait_str,
               actual_time,
               dep->line.designation,
               dep->destination,
               type);
    }
    
    free_departure_list(departures);
    return 0;
}

int main(int argc, char *argv[]) {
    // Initialize libcurl
    if (curl_global_init(CURL_GLOBAL_DEFAULT) != CURLE_OK) {
        fprintf(stderr, "Failed to initialize libcurl\n");
        return EXIT_FAILURE;
    }
    
    // Parse command line arguments
    CliArgs_t args;
    int parse_result = parse_args(argc, argv, &args);
    
    if (parse_result < 0) {
        print_usage(argv[0]);
        curl_global_cleanup();
        return EXIT_FAILURE;
    }
    
    if (parse_result == 1) {
        // Help was requested and already printed
        free_cli_args(&args);
        curl_global_cleanup();
        return EXIT_SUCCESS;
    }
    
    // Validate arguments
    if (validate_args(&args) != 0) {
        free_cli_args(&args);
        curl_global_cleanup();
        return EXIT_FAILURE;
    }
    
    // Handle help command
    if (args.command == CMD_HELP) {
        print_usage(argv[0]);
        free_cli_args(&args);
        curl_global_cleanup();
        return EXIT_SUCCESS;
    }
    
    // Create SL client
    SlClient_t *client = sl_client_new();
    if (!client) {
        fprintf(stderr, "Failed to create SL client\n");
        free_cli_args(&args);
        curl_global_cleanup();
        return EXIT_FAILURE;
    }
    
    int result = EXIT_SUCCESS;
    
    // Handle commands
    switch (args.command) {
        case CMD_SEARCH:
            if (handle_search(client, args.query) != 0) {
                result = EXIT_FAILURE;
            }
            break;
            
        case CMD_DEPARTURES:
            if (handle_departures(client, args.station, args.line, 
                                 args.transport_type, args.count, args.destination) != 0) {
                result = EXIT_FAILURE;
            }
            break;
            
        case CMD_HELP:
        default:
            print_usage(argv[0]);
            break;
    }
    
    // Cleanup
    sl_client_free(client);
    free_cli_args(&args);
    curl_global_cleanup();
    
    return result;
}
#ifndef TYPES_H
#define TYPES_H

#include <time.h>

// Structure to hold stop/station information
typedef struct {
    char *name;
    unsigned int id;
} stop_info_t;

// Structure to hold line information
typedef struct {
    char *designation;
    char *group_of_lines;
} line_t;

// Structure to hold departure information
typedef struct {
    char *destination;
    char *expected;
    line_t line;
} departure_t;

// Structure to hold search results
typedef struct {
    stop_info_t *stops;
    size_t count;
    size_t capacity;
} stop_list_t;

// Structure to hold departure results
typedef struct {
    departure_t *departures;
    size_t count;
    size_t capacity;
} departure_list_t;

// Command types
typedef enum {
    CMD_SEARCH,
    CMD_DEPARTURES,
    CMD_HELP
} command_type_t;

// CLI arguments structure
typedef struct {
    command_type_t command;
    char *query;
    char *station;
    char *line;
    char *transport_type;
    char *destination;
    int count;
} cli_args_t;

// HTTP response structure
typedef struct {
    char *data;
    size_t size;
} http_response_t;

// Function declarations for memory management
void free_stop_info(stop_info_t *stop);
void free_stop_list(stop_list_t *list);
void free_departure(departure_t *departure);
void free_departure_list(departure_list_t *list);
void free_cli_args(cli_args_t *args);
void free_http_response(http_response_t *response);

// Utility functions
stop_list_t *create_stop_list(void);
departure_list_t *create_departure_list(void);
int add_stop_to_list(stop_list_t *list, const char *name, unsigned int id);
int add_departure_to_list(departure_list_t *list, const char *destination, 
                         const char *expected, const char *designation, 
                         const char *group_of_lines);

#endif // TYPES_H
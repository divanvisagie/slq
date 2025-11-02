#ifndef TYPES_H
#define TYPES_H

#include <time.h>

// Structure to hold stop/station information
typedef struct {
    char *name;
    unsigned int id;
} StopInfo_t;

// Structure to hold line information
typedef struct {
    char *designation;
    char *group_of_lines;
} Line_t;

// Structure to hold departure information
typedef struct {
    char *destination;
    char *expected;
    Line_t line;
} Departure_t;

// Structure to hold search results
typedef struct {
    StopInfo_t *stops;
    size_t count;
    size_t capacity;
} StopList_t;

// Structure to hold departure results
typedef struct {
    Departure_t *departures;
    size_t count;
    size_t capacity;
} DepartureList_t;

// Command types
typedef enum {
    CMD_SEARCH,
    CMD_DEPARTURES,
    CMD_HELP
} CommandType_t;

// CLI arguments structure
typedef struct {
    CommandType_t command;
    char *query;
    char *station;
    char *line;
    char *transport_type;
    char *destination;
    int count;
} CliArgs_t;

// HTTP response structure
typedef struct {
    char *data;
    size_t size;
} HttpResponse_t;

// Function declarations for memory management
void free_stop_info(StopInfo_t *stop);
void free_stop_list(StopList_t *list);
void free_departure(Departure_t *departure);
void free_departure_list(DepartureList_t *list);
void free_cli_args(CliArgs_t *args);
void free_http_response(HttpResponse_t *response);

// Utility functions
StopList_t *create_stop_list(void);
DepartureList_t *create_departure_list(void);
int add_stop_to_list(StopList_t *list, const char *name, unsigned int id);
int add_departure_to_list(DepartureList_t *list, const char *destination, 
                         const char *expected, const char *designation, 
                         const char *group_of_lines);

#endif // TYPES_H
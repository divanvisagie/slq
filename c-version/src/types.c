#include "types.h"
#include <stdlib.h>
#include <string.h>

// Free a single stop_info structure
void free_stop_info(stop_info_t *stop) {
    if (stop) {
        free(stop->name);
        stop->name = NULL;
        stop->id = 0;
    }
}

// Free a stop_list structure and all its contents
void free_stop_list(stop_list_t *list) {
    if (list) {
        if (list->stops) {
            for (size_t i = 0; i < list->count; i++) {
                free_stop_info(&list->stops[i]);
            }
            free(list->stops);
        }
        free(list);
    }
}

// Free a single departure structure
void free_departure(departure_t *departure) {
    if (departure) {
        free(departure->destination);
        free(departure->expected);
        free(departure->line.designation);
        free(departure->line.group_of_lines);
        departure->destination = NULL;
        departure->expected = NULL;
        departure->line.designation = NULL;
        departure->line.group_of_lines = NULL;
    }
}

// Free a departure_list structure and all its contents
void free_departure_list(departure_list_t *list) {
    if (list) {
        if (list->departures) {
            for (size_t i = 0; i < list->count; i++) {
                free_departure(&list->departures[i]);
            }
            free(list->departures);
        }
        free(list);
    }
}

// Free CLI arguments structure
void free_cli_args(cli_args_t *args) {
    if (args) {
        free(args->query);
        free(args->station);
        free(args->line);
        free(args->transport_type);
        free(args->destination);
        args->query = NULL;
        args->station = NULL;
        args->line = NULL;
        args->transport_type = NULL;
        args->destination = NULL;
    }
}

// Free HTTP response structure
void free_http_response(http_response_t *response) {
    if (response) {
        free(response->data);
        response->data = NULL;
        response->size = 0;
    }
}

// Create a new stop list with initial capacity
stop_list_t *create_stop_list(void) {
    stop_list_t *list = malloc(sizeof(stop_list_t));
    if (!list) return NULL;
    
    list->capacity = 10;
    list->count = 0;
    list->stops = malloc(sizeof(stop_info_t) * list->capacity);
    
    if (!list->stops) {
        free(list);
        return NULL;
    }
    
    return list;
}

// Create a new departure list with initial capacity
departure_list_t *create_departure_list(void) {
    departure_list_t *list = malloc(sizeof(departure_list_t));
    if (!list) return NULL;
    
    list->capacity = 20;
    list->count = 0;
    list->departures = malloc(sizeof(departure_t) * list->capacity);
    
    if (!list->departures) {
        free(list);
        return NULL;
    }
    
    return list;
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

// Add a stop to the stop list, expanding capacity if needed
int add_stop_to_list(stop_list_t *list, const char *name, unsigned int id) {
    if (!list || !name) return -1;
    
    // Expand capacity if needed
    if (list->count >= list->capacity) {
        size_t new_capacity = list->capacity * 2;
        stop_info_t *new_stops = realloc(list->stops, sizeof(stop_info_t) * new_capacity);
        if (!new_stops) return -1;
        
        list->stops = new_stops;
        list->capacity = new_capacity;
    }
    
    // Add the new stop
    stop_info_t *stop = &list->stops[list->count];
    stop->name = strdup_safe(name);
    stop->id = id;
    
    if (!stop->name) return -1;
    
    list->count++;
    return 0;
}

// Add a departure to the departure list, expanding capacity if needed
int add_departure_to_list(departure_list_t *list, const char *destination, 
                         const char *expected, const char *designation, 
                         const char *group_of_lines) {
    if (!list || !destination || !expected || !designation) return -1;
    
    // Expand capacity if needed
    if (list->count >= list->capacity) {
        size_t new_capacity = list->capacity * 2;
        departure_t *new_departures = realloc(list->departures, sizeof(departure_t) * new_capacity);
        if (!new_departures) return -1;
        
        list->departures = new_departures;
        list->capacity = new_capacity;
    }
    
    // Add the new departure
    departure_t *departure = &list->departures[list->count];
    departure->destination = strdup_safe(destination);
    departure->expected = strdup_safe(expected);
    departure->line.designation = strdup_safe(designation);
    departure->line.group_of_lines = strdup_safe(group_of_lines);
    
    if (!departure->destination || !departure->expected || !departure->line.designation) {
        // Cleanup on failure
        free(departure->destination);
        free(departure->expected);
        free(departure->line.designation);
        free(departure->line.group_of_lines);
        return -1;
    }
    
    list->count++;
    return 0;
}
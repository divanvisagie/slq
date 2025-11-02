#include "types.h"
#include <stdlib.h>
#include <string.h>

void free_stop_info(StopInfo_t *stop) {
    if (stop) {
        free(stop->name);
        stop->name = NULL;
        stop->id = 0;
    }
}

void free_stop_list(StopList_t *list) {
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

void free_departure(Departure_t *departure) {
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

void free_departure_list(DepartureList_t *list) {
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

void free_cli_args(CliArgs_t *args) {
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

void free_http_response(HttpResponse_t *response) {
    if (response) {
        free(response->data);
        response->data = NULL;
        response->size = 0;
    }
}

StopList_t *create_stop_list(void) {
    StopList_t *list = malloc(sizeof(StopList_t));
    if (!list) return NULL;

    list->capacity = 10;
    list->count = 0;
    list->stops = malloc(sizeof(StopInfo_t) * list->capacity);

    if (!list->stops) {
        free(list);
        return NULL;
    }

    return list;
}

DepartureList_t *create_departure_list(void) {
    DepartureList_t *list = malloc(sizeof(DepartureList_t));
    if (!list) return NULL;

    list->capacity = 20;
    list->count = 0;
    list->departures = malloc(sizeof(Departure_t) * list->capacity);

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
int add_stop_to_list(StopList_t *list, const char *name, unsigned int id) {
    if (!list || !name) return -1;

    // Expand capacity if needed
    if (list->count >= list->capacity) {
        size_t new_capacity = list->capacity * 2;
        StopInfo_t *new_stops = realloc(list->stops, sizeof(StopInfo_t) * new_capacity);
        if (!new_stops) return -1;

        list->stops = new_stops;
        list->capacity = new_capacity;
    }

    // Add the new stop
    StopInfo_t *stop = &list->stops[list->count];
    stop->name = strdup_safe(name);
    stop->id = id;

    if (!stop->name) return -1;

    list->count++;
    return 0;
}

// Add a departure to the departure list, expanding capacity if needed
int add_departure_to_list(DepartureList_t *list, const char *destination,
                         const char *expected, const char *designation,
                         const char *group_of_lines) {
    if (!list || !destination || !expected || !designation) return -1;

    // Expand capacity if needed
    if (list->count >= list->capacity) {
        size_t new_capacity = list->capacity * 2;
        Departure_t *new_departures = realloc(list->departures, sizeof(Departure_t) * new_capacity);
        if (!new_departures) return -1;

        list->departures = new_departures;
        list->capacity = new_capacity;
    }

    // Add the new departure
    Departure_t *departure = &list->departures[list->count];
    departure->destination = strdup_safe(destination);
    departure->expected = strdup_safe(expected);
    departure->line.designation = strdup_safe(designation);
    departure->line.group_of_lines = strdup_safe(group_of_lines);

    // Cleanup on failure
    if (!departure->destination || !departure->expected || !departure->line.designation) {
        free(departure->destination);
        free(departure->expected);
        free(departure->line.designation);
        free(departure->line.group_of_lines);
        return -1;
    }

    list->count++;
    return 0;
}

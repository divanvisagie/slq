#ifndef CLIENT_H
#define CLIENT_H

#include "types.h"
#include <curl/curl.h>

// Base URLs for SL API
#define SL_SITES_URL "https://transport.integration.sl.se/v1/sites?expand=true"
#define SL_DEPARTURES_URL_FMT "https://transport.integration.sl.se/v1/sites/%u/departures"

// HTTP client structure
typedef struct {
    CURL *curl;
    struct curl_slist *headers;
} SlClient_t;

// Function declarations for HTTP client
SlClient_t *sl_client_new(void);
void sl_client_free(SlClient_t *client);

// HTTP response callback for libcurl
size_t write_response_callback(void *contents, size_t size, size_t nmemb, HttpResponse_t *response);

// Core API functions
int sl_search_stops(SlClient_t *client, const char *query, StopList_t **result);
int sl_get_departures(SlClient_t *client, const char *station, 
                     const char *line_filter, const char *transport_filter,
                     const char *destination_filter, DepartureList_t **result);

// Helper functions
int sl_get_sites(SlClient_t *client, StopList_t **sites);
unsigned int sl_find_station_id(SlClient_t *client, const char *station_name);

// JSON parsing functions
int parse_sites_json(const char *json_data, StopList_t **result);
int parse_departures_json(const char *json_data, DepartureList_t **result);

// Filtering functions
void filter_departures_by_line(DepartureList_t *departures, const char *line);
void filter_departures_by_transport(DepartureList_t *departures, const char *transport_type);
void filter_departures_by_destination(DepartureList_t *departures, const char *destination);

// Time parsing and calculation functions
int parse_departure_time(const char *time_str, char *time_output, size_t output_size);
int calculate_wait_minutes(const char *time_str);

// String utility functions
char *str_to_lower(const char *str);
int str_contains_case_insensitive(const char *haystack, const char *needle);
int line_matches_filter(const char *designation, const char *line_filter);

#endif // CLIENT_H
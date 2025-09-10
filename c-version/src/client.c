#include "client.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <ctype.h>
#include <jansson.h>

// Create a new SL client
sl_client_t *sl_client_new(void) {
    sl_client_t *client = malloc(sizeof(sl_client_t));
    if (!client) return NULL;
    
    client->curl = curl_easy_init();
    if (!client->curl) {
        free(client);
        return NULL;
    }
    
    // Set up common headers
    client->headers = NULL;
    client->headers = curl_slist_append(client->headers, "Accept: application/json");
    client->headers = curl_slist_append(client->headers, "User-Agent: slq/1.0");
    
    // Set common curl options
    curl_easy_setopt(client->curl, CURLOPT_HTTPHEADER, client->headers);
    curl_easy_setopt(client->curl, CURLOPT_TIMEOUT, 30L);
    curl_easy_setopt(client->curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(client->curl, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(client->curl, CURLOPT_WRITEFUNCTION, write_response_callback);
    
    return client;
}

// Free SL client resources
void sl_client_free(sl_client_t *client) {
    if (client) {
        if (client->curl) {
            curl_easy_cleanup(client->curl);
        }
        if (client->headers) {
            curl_slist_free_all(client->headers);
        }
        free(client);
    }
}

// Callback function to write HTTP response data
size_t write_response_callback(void *contents, size_t size, size_t nmemb, http_response_t *response) {
    size_t total_size = size * nmemb;
    
    char *new_data = realloc(response->data, response->size + total_size + 1);
    if (!new_data) {
        return 0; // Out of memory
    }
    
    response->data = new_data;
    memcpy(&(response->data[response->size]), contents, total_size);
    response->size += total_size;
    response->data[response->size] = '\0';
    
    return total_size;
}

// Search for stops matching a query
int sl_search_stops(sl_client_t *client, const char *query, stop_list_t **result) {
    if (!client || !query || !result) return -1;
    
    http_response_t response = {0};
    
    // Set URL and response structure
    curl_easy_setopt(client->curl, CURLOPT_URL, SL_SITES_URL);
    curl_easy_setopt(client->curl, CURLOPT_WRITEDATA, &response);
    
    // Perform the request
    CURLcode res = curl_easy_perform(client->curl);
    if (res != CURLE_OK) {
        fprintf(stderr, "HTTP request failed: %s\n", curl_easy_strerror(res));
        free_http_response(&response);
        return -1;
    }
    
    // Check HTTP status code
    long response_code;
    curl_easy_getinfo(client->curl, CURLINFO_RESPONSE_CODE, &response_code);
    if (response_code != 200) {
        fprintf(stderr, "HTTP request failed with status %ld\n", response_code);
        free_http_response(&response);
        return -1;
    }
    
    // Parse JSON and filter results
    stop_list_t *all_sites = NULL;
    if (parse_sites_json(response.data, &all_sites) != 0) {
        fprintf(stderr, "Failed to parse JSON response\n");
        free_http_response(&response);
        return -1;
    }
    
    free_http_response(&response);
    
    // Filter sites by query
    stop_list_t *filtered_sites = create_stop_list();
    if (!filtered_sites) {
        free_stop_list(all_sites);
        return -1;
    }
    
    char *query_lower = str_to_lower(query);
    if (!query_lower) {
        free_stop_list(all_sites);
        free_stop_list(filtered_sites);
        return -1;
    }
    
    for (size_t i = 0; i < all_sites->count; i++) {
        char *name_lower = str_to_lower(all_sites->stops[i].name);
        if (name_lower && strstr(name_lower, query_lower)) {
            add_stop_to_list(filtered_sites, all_sites->stops[i].name, all_sites->stops[i].id);
        }
        free(name_lower);
    }
    
    free(query_lower);
    free_stop_list(all_sites);
    
    *result = filtered_sites;
    return 0;
}

// Get departures for a station
int sl_get_departures(sl_client_t *client, const char *station, 
                     const char *line_filter, const char *transport_filter,
                     const char *destination_filter, departure_list_t **result) {
    if (!client || !station || !result) return -1;
    
    // Find station ID if station is not numeric
    unsigned int station_id;
    char *endptr;
    station_id = strtoul(station, &endptr, 10);
    
    if (*endptr != '\0') {
        // Station is not numeric, find by name
        station_id = sl_find_station_id(client, station);
        if (station_id == 0) {
            fprintf(stderr, "Error: No station found for '%s'\n", station);
            return -1;
        }
    }
    
    // Build departures URL
    char url[256];
    snprintf(url, sizeof(url), SL_DEPARTURES_URL_FMT, station_id);
    
    http_response_t response = {0};
    
    // Set URL and response structure
    curl_easy_setopt(client->curl, CURLOPT_URL, url);
    curl_easy_setopt(client->curl, CURLOPT_WRITEDATA, &response);
    
    // Perform the request
    CURLcode res = curl_easy_perform(client->curl);
    if (res != CURLE_OK) {
        fprintf(stderr, "HTTP request failed: %s\n", curl_easy_strerror(res));
        free_http_response(&response);
        return -1;
    }
    
    // Check HTTP status code
    long response_code;
    curl_easy_getinfo(client->curl, CURLINFO_RESPONSE_CODE, &response_code);
    if (response_code != 200) {
        fprintf(stderr, "HTTP request failed with status %ld\n", response_code);
        free_http_response(&response);
        return -1;
    }
    
    // Parse JSON
    departure_list_t *departures = NULL;
    if (parse_departures_json(response.data, &departures) != 0) {
        fprintf(stderr, "Failed to parse departures JSON\n");
        free_http_response(&response);
        return -1;
    }
    
    free_http_response(&response);
    
    // Apply filters
    if (line_filter) {
        filter_departures_by_line(departures, line_filter);
    }
    
    if (transport_filter) {
        filter_departures_by_transport(departures, transport_filter);
    }
    
    if (destination_filter) {
        filter_departures_by_destination(departures, destination_filter);
    }
    
    *result = departures;
    return 0;
}

// Get all sites from SL API
int sl_get_sites(sl_client_t *client, stop_list_t **sites) {
    if (!client || !sites) return -1;
    
    http_response_t response = {0};
    
    curl_easy_setopt(client->curl, CURLOPT_URL, SL_SITES_URL);
    curl_easy_setopt(client->curl, CURLOPT_WRITEDATA, &response);
    
    CURLcode res = curl_easy_perform(client->curl);
    if (res != CURLE_OK) {
        fprintf(stderr, "HTTP request failed: %s\n", curl_easy_strerror(res));
        free_http_response(&response);
        return -1;
    }
    
    long response_code;
    curl_easy_getinfo(client->curl, CURLINFO_RESPONSE_CODE, &response_code);
    if (response_code != 200) {
        fprintf(stderr, "HTTP request failed with status %ld\n", response_code);
        free_http_response(&response);
        return -1;
    }
    
    int result = parse_sites_json(response.data, sites);
    free_http_response(&response);
    
    return result;
}

// Find station ID by name
unsigned int sl_find_station_id(sl_client_t *client, const char *station_name) {
    if (!client || !station_name) return 0;
    
    stop_list_t *sites = NULL;
    if (sl_get_sites(client, &sites) != 0) {
        return 0;
    }
    
    char *name_lower = str_to_lower(station_name);
    if (!name_lower) {
        free_stop_list(sites);
        return 0;
    }
    
    unsigned int found_id = 0;
    for (size_t i = 0; i < sites->count; i++) {
        char *site_name_lower = str_to_lower(sites->stops[i].name);
        if (site_name_lower && strstr(site_name_lower, name_lower)) {
            found_id = sites->stops[i].id;
            free(site_name_lower);
            break;
        }
        free(site_name_lower);
    }
    
    free(name_lower);
    free_stop_list(sites);
    
    return found_id;
}

// Parse sites JSON response
int parse_sites_json(const char *json_data, stop_list_t **result) {
    if (!json_data || !result) return -1;
    
    json_error_t error;
    json_t *root = json_loads(json_data, 0, &error);
    if (!root) {
        fprintf(stderr, "JSON parsing error: %s\n", error.text);
        return -1;
    }
    
    if (!json_is_array(root)) {
        fprintf(stderr, "Expected JSON array\n");
        json_decref(root);
        return -1;
    }
    
    stop_list_t *sites = create_stop_list();
    if (!sites) {
        json_decref(root);
        return -1;
    }
    
    size_t index;
    json_t *site;
    json_array_foreach(root, index, site) {
        json_t *name_obj = json_object_get(site, "name");
        json_t *id_obj = json_object_get(site, "id");
        
        if (json_is_string(name_obj) && json_is_integer(id_obj)) {
            const char *name = json_string_value(name_obj);
            unsigned int id = (unsigned int)json_integer_value(id_obj);
            
            if (add_stop_to_list(sites, name, id) != 0) {
                fprintf(stderr, "Failed to add stop to list\n");
                free_stop_list(sites);
                json_decref(root);
                return -1;
            }
        }
    }
    
    json_decref(root);
    *result = sites;
    return 0;
}

// Parse departures JSON response
int parse_departures_json(const char *json_data, departure_list_t **result) {
    if (!json_data || !result) return -1;
    
    json_error_t error;
    json_t *root = json_loads(json_data, 0, &error);
    if (!root) {
        fprintf(stderr, "JSON parsing error: %s\n", error.text);
        return -1;
    }
    
    json_t *departures_obj = json_object_get(root, "departures");
    if (!json_is_array(departures_obj)) {
        fprintf(stderr, "Expected departures array\n");
        json_decref(root);
        return -1;
    }
    
    departure_list_t *departures = create_departure_list();
    if (!departures) {
        json_decref(root);
        return -1;
    }
    
    size_t index;
    json_t *departure;
    json_array_foreach(departures_obj, index, departure) {
        json_t *destination_obj = json_object_get(departure, "destination");
        json_t *expected_obj = json_object_get(departure, "expected");
        json_t *line_obj = json_object_get(departure, "line");
        
        if (json_is_string(destination_obj) && json_is_string(expected_obj) && json_is_object(line_obj)) {
            json_t *designation_obj = json_object_get(line_obj, "designation");
            json_t *group_obj = json_object_get(line_obj, "group_of_lines");
            
            if (json_is_string(designation_obj)) {
                const char *destination = json_string_value(destination_obj);
                const char *expected = json_string_value(expected_obj);
                const char *designation = json_string_value(designation_obj);
                const char *group = json_is_string(group_obj) ? json_string_value(group_obj) : NULL;
                
                // Only add departures that have a group_of_lines (transport type)
                if (group) {
                    if (add_departure_to_list(departures, destination, expected, designation, group) != 0) {
                        fprintf(stderr, "Failed to add departure to list\n");
                        free_departure_list(departures);
                        json_decref(root);
                        return -1;
                    }
                }
            }
        }
    }
    
    json_decref(root);
    *result = departures;
    return 0;
}

// Filter departures by line number
void filter_departures_by_line(departure_list_t *departures, const char *line) {
    if (!departures || !line) return;
    
    size_t write_idx = 0;
    for (size_t read_idx = 0; read_idx < departures->count; read_idx++) {
        if (line_matches_filter(departures->departures[read_idx].line.designation, line)) {
            if (write_idx != read_idx) {
                departures->departures[write_idx] = departures->departures[read_idx];
            }
            write_idx++;
        } else {
            // Free the filtered out departure
            free_departure(&departures->departures[read_idx]);
        }
    }
    departures->count = write_idx;
}

// Filter departures by transport type
void filter_departures_by_transport(departure_list_t *departures, const char *transport_type) {
    if (!departures || !transport_type) return;
    
    char *transport_lower = str_to_lower(transport_type);
    if (!transport_lower) return;
    
    size_t write_idx = 0;
    for (size_t read_idx = 0; read_idx < departures->count; read_idx++) {
        const char *group = departures->departures[read_idx].line.group_of_lines;
        if (group) {
            char *group_lower = str_to_lower(group);
            int matches = 0;
            
            if (group_lower) {
                if (strcmp(transport_lower, "metro") == 0) {
                    matches = strstr(group_lower, "tunnelbanan") != NULL;
                } else if (strcmp(transport_lower, "bus") == 0) {
                    matches = strstr(group_lower, "buss") != NULL || strstr(group_lower, "närtrafiken") != NULL;
                } else if (strcmp(transport_lower, "train") == 0) {
                    matches = strstr(group_lower, "pendeltåg") != NULL || strstr(group_lower, "roslagsbanan") != NULL;
                } else if (strcmp(transport_lower, "tram") == 0) {
                    matches = strstr(group_lower, "spårväg") != NULL;
                }
                free(group_lower);
            }
            
            if (matches) {
                if (write_idx != read_idx) {
                    departures->departures[write_idx] = departures->departures[read_idx];
                }
                write_idx++;
            } else {
                free_departure(&departures->departures[read_idx]);
            }
        } else {
            free_departure(&departures->departures[read_idx]);
        }
    }
    
    free(transport_lower);
    departures->count = write_idx;
}

// Filter departures by destination
void filter_departures_by_destination(departure_list_t *departures, const char *destination) {
    if (!departures || !destination) return;
    
    // Check if destination is numeric (ID)
    char *endptr;
    unsigned int dest_id = strtoul(destination, &endptr, 10);
    int is_numeric = (*endptr == '\0');
    
    char *dest_lower = str_to_lower(destination);
    if (!dest_lower) return;
    
    size_t write_idx = 0;
    for (size_t read_idx = 0; read_idx < departures->count; read_idx++) {
        int matches = 0;
        
        if (is_numeric) {
            // Check if destination contains the ID as string
            char id_str[32];
            snprintf(id_str, sizeof(id_str), "%u", dest_id);
            matches = strstr(departures->departures[read_idx].destination, id_str) != NULL;
        } else {
            // Name-based filtering
            matches = str_contains_case_insensitive(departures->departures[read_idx].destination, dest_lower);
        }
        
        if (matches) {
            if (write_idx != read_idx) {
                departures->departures[write_idx] = departures->departures[read_idx];
            }
            write_idx++;
        } else {
            free_departure(&departures->departures[read_idx]);
        }
    }
    
    free(dest_lower);
    departures->count = write_idx;
}

// Parse departure time and extract HH:MM format
int parse_departure_time(const char *time_str, char *time_output, size_t output_size) {
    if (!time_str || !time_output || output_size < 6) return -1;
    
    struct tm tm;
    memset(&tm, 0, sizeof(tm));
    
    // Parse format: 2025-09-09T13:33:30
    if (strptime(time_str, "%Y-%m-%dT%H:%M:%S", &tm) == NULL) {
        return -1;
    }
    
    snprintf(time_output, output_size, "%02d:%02d", tm.tm_hour, tm.tm_min);
    return 0;
}

// Calculate wait minutes from departure time
int calculate_wait_minutes(const char *time_str) {
    if (!time_str) return -1;
    
    struct tm departure_tm;
    memset(&departure_tm, 0, sizeof(departure_tm));
    
    // Parse departure time
    if (strptime(time_str, "%Y-%m-%dT%H:%M:%S", &departure_tm) == NULL) {
        return -1;
    }
    
    // Get current time
    time_t now = time(NULL);
    struct tm *current_tm = localtime(&now);
    
    // Convert to time_t for comparison
    time_t departure_time = mktime(&departure_tm);
    time_t current_time = mktime(current_tm);
    
    // Calculate difference in minutes
    double diff_seconds = difftime(departure_time, current_time);
    int diff_minutes = (int)(diff_seconds / 60.0);
    
    return diff_minutes > 0 ? diff_minutes : 0;
}

// Convert string to lowercase
char *str_to_lower(const char *str) {
    if (!str) return NULL;
    
    size_t len = strlen(str);
    char *lower = malloc(len + 1);
    if (!lower) return NULL;
    
    for (size_t i = 0; i < len; i++) {
        lower[i] = tolower((unsigned char)str[i]);
    }
    lower[len] = '\0';
    
    return lower;
}

// Case-insensitive substring search
int str_contains_case_insensitive(const char *haystack, const char *needle) {
    if (!haystack || !needle) return 0;
    
    char *haystack_lower = str_to_lower(haystack);
    char *needle_lower = str_to_lower(needle);
    
    int result = 0;
    if (haystack_lower && needle_lower) {
        result = strstr(haystack_lower, needle_lower) != NULL;
    }
    
    free(haystack_lower);
    free(needle_lower);
    
    return result;
}

// Check if line designation matches filter (including variants like 28s)
int line_matches_filter(const char *designation, const char *line_filter) {
    if (!designation || !line_filter) return 0;
    
    // Exact match first
    if (strcasecmp(designation, line_filter) == 0) {
        return 1;
    }
    
    // Check if designation starts with line_filter and is followed by a letter
    size_t filter_len = strlen(line_filter);
    if (strncasecmp(designation, line_filter, filter_len) == 0) {
        if (strlen(designation) > filter_len) {
            char next_char = designation[filter_len];
            return isalpha((unsigned char)next_char);
        }
    }
    
    return 0;
}
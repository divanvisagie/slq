# Journey Planning Feature Proposal

## Overview

This document outlines a proposal for implementing full journey planning functionality in the `slq` CLI tool. Currently, the `journey` command only finds matching stations and suggests using the `departures` command instead.

## Current State

The existing `journey` command implementation:
- Searches for origin and destination stations
- Lists matching stations for both endpoints
- Displays a note that "Full journey planning requires complex API integration"
- Suggests using `slq departures <station>` instead

## Proposed Implementation

### API Requirements

To implement proper journey planning, we would need to integrate with SL's journey planning APIs:

- **SL Reseplanerare API**: `https://api.sl.se/api2/TravelplannerV3_1/trip.json`
- **Alternative**: Use SL's GraphQL API or newer REST endpoints
- **API Key**: Would require registration and API key management

### Functional Requirements

1. **Route Calculation**
   - Find optimal routes between two stations
   - Support multiple route options (fastest, fewest transfers, etc.)
   - Handle real-time disruptions and delays

2. **Time Planning**
   - Support departure time or arrival time preferences
   - Show estimated journey times
   - Display connection details and waiting times

3. **Transport Mode Selection**
   - Allow filtering by transport types (metro, bus, train, etc.)
   - Support accessibility requirements
   - Handle walking distances and transfer times

4. **Output Format**
   - Clear step-by-step journey instructions
   - Departure and arrival times for each leg
   - Platform/stop information
   - Total journey time and cost information

### Technical Implementation

#### API Integration
```rust
pub struct JourneyPlanner {
    api_key: String,
    client: reqwest::Client,
}

pub struct JourneyRequest {
    pub origin_id: String,
    pub destination_id: String,
    pub departure_time: Option<DateTime<Local>>,
    pub arrival_time: Option<DateTime<Local>>,
    pub transport_modes: Vec<TransportMode>,
}

pub struct Journey {
    pub legs: Vec<JourneyLeg>,
    pub total_duration: Duration,
    pub total_cost: Option<f64>,
    pub accessibility: AccessibilityInfo,
}
```

#### CLI Interface
```bash
# Basic journey planning
slq journey "T-Centralen" "Arlanda"

# With departure time
slq journey "T-Centralen" "Arlanda" --depart "14:30"

# With arrival time preference
slq journey "T-Centralen" "Arlanda" --arrive "16:00"

# Filter by transport modes
slq journey "T-Centralen" "Arlanda" --modes metro,train

# Multiple route options
slq journey "T-Centralen" "Arlanda" --alternatives 3

# Accessibility requirements
slq journey "T-Centralen" "Arlanda" --accessible
```

### Example Output Format

```
Journey from T-Centralen to Arlanda Airport
Departure: Today 14:30 → Arrival: Today 15:12 (42 minutes)

Route 1 (Recommended - Fastest):
├─ 14:30  T-Centralen                  Platform 1
│  🚇 Metro Blue Line 11 → Kungsträdgården
├─ 14:33  Kungsträdgården              Platform 1
│  🚇 Metro Blue Line 10 → Hjulsta
├─ 14:51  Arlanda Central              Platform 2
│  🚆 Arlanda Express → Arlanda Airport
└─ 15:12  Arlanda Airport Terminal 5

Total: 42 min, 2 transfers, Cost: ~180 SEK

Alternative routes available (--alternatives flag for more)
```

### Implementation Challenges

1. **API Key Management**
   - Secure storage and configuration
   - Rate limiting and quota management
   - Error handling for API failures

2. **Complex Data Models**
   - Journey legs with different transport modes
   - Real-time data integration
   - Disruption and delay handling

3. **User Experience**
   - Clear output formatting for complex journey data
   - Handling multiple route options
   - Error messages for unreachable destinations

4. **Performance**
   - Caching of station data and common routes
   - Timeout handling for slow API responses
   - Fallback options when primary APIs fail

### Development Phases

#### Phase 1: API Integration Foundation
- Set up SL API client with authentication
- Implement basic journey request/response models
- Add configuration for API keys

#### Phase 2: Core Journey Planning
- Implement single route calculation
- Basic output formatting
- Error handling for common failure cases

#### Phase 3: Enhanced Features
- Multiple route alternatives
- Transport mode filtering
- Time preference handling (depart/arrive)

#### Phase 4: Advanced Features
- Real-time disruption integration
- Accessibility support
- Cost calculations
- Performance optimizations

### Configuration Requirements

The feature would require additional configuration:

```toml
# ~/.config/slq/config.toml
[api]
sl_api_key = "your-api-key-here"
sl_api_base_url = "https://api.sl.se/api2/"

[journey]
default_walk_speed = "normal"  # slow, normal, fast
max_alternatives = 5
default_transport_modes = ["metro", "bus", "train", "tram"]
```

### Testing Strategy

1. **Unit Tests**
   - API client functionality
   - Data model parsing
   - Journey calculation logic

2. **Integration Tests**
   - End-to-end journey planning workflows
   - API error handling
   - Configuration management

3. **Black-box Tests**
   - CLI command interface
   - Output format validation
   - Error message clarity

### Migration Strategy

1. **Deprecation Notice**
   - Add warning to current `journey` command about upcoming changes
   - Provide timeline for full implementation

2. **Feature Flag**
   - Implement behind optional feature flag
   - Allow testing with `--experimental-journey` flag

3. **Gradual Rollout**
   - Beta testing with limited functionality
   - Gather user feedback before full release

## Decision Points

1. **API Choice**: Which SL API to use (REST vs GraphQL vs legacy)
2. **API Key Distribution**: How to handle API key requirements for users
3. **Offline Support**: Whether to cache data for limited offline functionality
4. **Scope**: Which advanced features to include in initial release

## Alternatives Considered

1. **Keep Simple Station Finder**: Maintain current minimal implementation
2. **External Tool Integration**: Suggest users use existing apps/websites
3. **Web Scraping**: Use SL's website directly (not recommended due to reliability)

## Conclusion

While journey planning would significantly enhance the tool's usefulness, it requires substantial development effort and introduces API key management complexity. The current station search and departures functionality may be sufficient for most CLI use cases, where users often prefer to manually plan connections using departure information.

This proposal should be considered for a future major version release when the core functionality is stable and there's demonstrated user demand for full journey planning capabilities.
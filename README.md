# Decentralized Public Lighting and Electrical Infrastructure

A comprehensive blockchain-based system for managing public lighting and electrical infrastructure using Clarity smart contracts.

## System Overview

This system consists of five interconnected smart contracts that manage different aspects of public lighting and electrical infrastructure:

### 1. Street Light Maintenance Contract (`street-light-maintenance.clar`)
- Coordinates repair requests and work orders
- Manages bulb replacement scheduling
- Handles energy-efficient LED upgrade programs
- Tracks maintenance history and costs

### 2. Traffic Signal Synchronization Contract (`traffic-signal-sync.clar`)
- Manages traffic light timing patterns
- Coordinates signal synchronization for optimal traffic flow
- Handles emergency override situations
- Tracks performance metrics

### 3. Holiday Lighting Installation Contract (`holiday-lighting.clar`)
- Coordinates seasonal lighting displays
- Manages installation and removal schedules
- Tracks public building and street decorations
- Handles budget allocation for holiday displays

### 4. Emergency Lighting Systems Contract (`emergency-lighting.clar`)
- Maintains backup lighting for critical infrastructure
- Monitors tunnel, bridge, and public facility lighting
- Handles emergency activation protocols
- Tracks system reliability and uptime

### 5. Electrical Utility Coordination Contract (`electrical-utility.clar`)
- Manages power supply distribution
- Coordinates electrical infrastructure maintenance
- Handles utility billing and cost allocation
- Tracks energy consumption and efficiency

## Key Features

- **Decentralized Management**: No single point of failure
- **Transparent Operations**: All activities recorded on blockchain
- **Cost Tracking**: Comprehensive financial monitoring
- **Maintenance Scheduling**: Automated work order management
- **Emergency Response**: Rapid response protocols for critical issues
- **Energy Efficiency**: LED upgrade tracking and energy monitoring

## Data Structures

Each contract maintains relevant data maps for:
- Equipment inventory and status
- Work orders and maintenance requests
- Cost tracking and budget allocation
- Performance metrics and analytics
- User permissions and access control

## Access Control

The system implements role-based access control with:
- **Contract Owner**: Full administrative access
- **Operators**: Day-to-day operational management
- **Technicians**: Field work and maintenance updates
- **Public**: Read-only access to relevant information

## Installation and Deployment

1. Install Clarinet CLI
2. Clone this repository
3. Run tests: `npm test`
4. Deploy contracts using Clarinet

## Testing

The system includes comprehensive tests using Vitest covering:
- Contract deployment and initialization
- Core functionality testing
- Error handling and edge cases
- Access control verification
- Data integrity checks

## Usage Examples

### Reporting a Street Light Issue
\`\`\`clarity
(contract-call? .street-light-maintenance report-issue u123 "Bulb burned out" u1000)
\`\`\`

### Scheduling Holiday Lighting
\`\`\`clarity
(contract-call? .holiday-lighting schedule-installation "Main Street" u1640995200 u1641081600)
\`\`\`

### Emergency Lighting Activation
\`\`\`clarity
(contract-call? .emergency-lighting activate-emergency-mode u456 "Power outage")
\`\`\`

## Contract Addresses

After deployment, update this section with the actual contract addresses on the Stacks blockchain.

## Contributing

Please read the PR-DETAILS.md file for contribution guidelines and development workflow.

## License

This project is licensed under the MIT License.

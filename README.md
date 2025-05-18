# CarbonTrack

CarbonTrack is a decentralized carbon offset verification and trading platform built on Clarity smart contracts where carbon reduction projects are verified on-chain and earn tokens based on offset purchases and impact ratings.

## Overview

This smart contract enables a carbon offset platform with the following features:

- **Project Registration**: Organizations can register carbon reduction projects with cryptographic hashing
- **On-chain Verification**: Verifier organizations validate project authenticity
- **Offset Tracking**: System tracks carbon offset purchases from buyers
- **Impact Ratings**: Organizations rate project environmental impact on a scale of 1-5
- **Token Rewards**: Project owners earn tokens based on offsets and impact ratings
- **Reputation System**: Organizations build reputation through positive contributions

## Contract Functions

### Organization Management
- `register-organization`: Register as a new organization with name and type
- `update-organization`: Update your organization information
- `get-organization-info`: Get information about an organization

### Project Management
- `register-project`: Register a new carbon project with description and project hash
- `get-project`: Get information about a project
- `get-total-projects`: Get the total number of projects on the platform

### Verification System
- `verify-project`: Verify the authenticity of a carbon project
- `get-project-verification`: Check if an organization has verified a project

### Offset System
- `purchase-offset`: Purchase carbon offsets from a verified project
- `get-carbon-offset`: Check an organization's offset purchase record

### Rating System
- `rate-project-impact`: Rate the environmental impact of a project (1-5)
- `get-impact-rating`: Get an organization's impact rating for a project

## Reward Mechanisms

The contract includes several token reward mechanisms:

1. **Verification Rewards**:
   - Verifiers who validate projects receive 5 tokens and 1 reputation point
   - Project owners receive 50 tokens and 10 reputation points when their project is verified by 3+ organizations

2. **Offset Rewards**:
   - Project owners receive 10 tokens for each carbon offset unit purchased

3. **Impact Rewards**:
   - Organizations who rate projects receive 2 tokens and 1 reputation point
   - Project owners receive 20 tokens and 5 reputation points for highly rated projects (4-5 stars)

## Development

This contract is designed to be deployed on the Stacks blockchain and can be tested using Clarinet.
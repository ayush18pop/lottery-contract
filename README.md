# Lottery Smart Contract (Chainlink VRF & Automation)

This project implements a decentralized lottery using Solidity, Chainlink VRF v2.5 for randomness, and Chainlink Automation for upkeep. It is built and tested with Foundry.

## Features

- **Raffle Contract:** Users enter by paying an entrance fee. A winner is picked at intervals using Chainlink VRF.
- **Chainlink VRF:** Provides provable randomness for winner selection.
- **Chainlink Automation:** Triggers upkeep to request randomness and pick a winner.
- **Configurable:** Supports local and Sepolia testnet deployments.

## Project Structure

- `src/Raffle.sol` — Main lottery contract
- `script/DeployRaffle.s.sol` — Deployment script
- `script/HelperConfig.s.sol` — Network configuration
- `script/Interactions.s.sol` — Scripts for subscription, funding, and consumer management
- `test/unit/RaffleTest.t.sol` — Unit tests
- `MakeFile` — Build, test, and deploy automation
- `.env` — Store sensitive variables (RPC URL, private key, Etherscan API key)

## Setup

### 1. Install Dependencies

```sh
make install
```

### 2. Configure `.env`

Add the following to your `.env` file:

```
SEPOLIA_RPC_URL=your_sepolia_rpc_url
PRIVATE_KEY=your_private_key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### 3. Build & Test

```sh
make build
make test
```

## Deployment & Chainlink Setup

### 1. Deploy Contract

```sh
make deploy ARGS="--network sepolia"
```

### 2. Create VRF Subscription

```sh
make createSubscription ARGS="--network sepolia"
```

### 3. Fund Subscription

```sh
make fundSubscription ARGS="--network sepolia"
```

### 4. Add Consumer

```sh
make addConsumer ARGS="--network sepolia"
```

### 5. Participate in Raffle

Call `enterRaffle` on the deployed contract using your wallet or a script.

## Notes

- Ensure your VRF subscription is funded and your contract is added as a consumer.
- If VRF requests are pending, check LINK balance and callback gas limit.
- Use Chainlink UI to monitor subscription status and fulfillments.

## License

MIT

Configure .env

Build & Test

Deployment & Chainlink Setup
Deploy Contract

Create VRF Subscription

Fund Subscription

Add Consumer

Participate in Raffle

Call enterRaffle on the deployed contract.
Notes
Ensure your VRF subscription is funded and your contract is added as a consumer.
If VRF requests are pending, check LINK balance and callback gas limit.
Use Chainlink UI to monitor subscription status and fulfillments.
License
MIT

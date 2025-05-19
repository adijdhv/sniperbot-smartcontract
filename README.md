# VirtualsSniper

A smart contract for sniping tokens on Uniswap V2 compatible DEXs with security features and error handling.

## Features

- Uniswap V2 token sniping with slippage protection
- Multi-hop path trading
- Security with ReentrancyGuard, Pausable, and Ownable2Step
- Emergency pause functionality
- Token and ETH withdrawal functions

## Setup

```bash
# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts
forge install Uniswap/v2-periphery

# Build contracts
forge build

# Run tests
forge test -vvv
```

## Deployment

To deploy to a network:
```
forge script script/Deploy.s.sol:DeployVirtualsSniper  --rpc-url $RPC_URL_Base_Sepolia   --private-key $PRIVATE_KEY   --broadcast   --verify   --etherscan-api-key $ETHERSCAN_API_KEY   -vvv
 
```
## License

MIT
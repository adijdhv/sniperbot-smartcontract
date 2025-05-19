#!/bin/bash

# Setup colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print banner
echo -e "${GREEN}"
echo "==============================================="
echo "       VirtualsSniper Deployment Helper        "
echo "==============================================="
echo -e "${NC}"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}No .env file found. Creating template...${NC}"
    cat > .env << EOF
# Network configuration
NETWORK=goerli
RPC_MAINNET=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
RPC_GOERLI=https://eth-goerli.g.alchemy.com/v2/YOUR_API_KEY

# Deployment and verification
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key

# Contract interaction
CONTRACT_ADDRESS=deployed_contract_address
FUND_AMOUNT=1000000000000000000  # 1 ETH in wei
SNIPER_ADDRESS=deployed_contract_address
TOKEN_ADDRESS=token_to_snipe_address
AMOUNT_IN=100000000000000000  # 0.1 ETH in wei
SLIPPAGE_PERCENT=1  # 1%
DEADLINE_SECONDS=300  # 5 minutes
EOF
    echo -e "${GREEN}Created .env template. Please edit it with your values.${NC}"
    exit 1
fi

# Source .env file
source .env

# Function to display help
show_help() {
    echo -e "${GREEN}Available commands:${NC}"
    echo -e "  ${YELLOW}setup${NC}      - Install dependencies"
    echo -e "  ${YELLOW}build${NC}      - Build the contracts"
    echo -e "  ${YELLOW}test${NC}       - Run the tests"
    echo -e "  ${YELLOW}deploy${NC}     - Deploy the contract"
    echo -e "  ${YELLOW}fund${NC}       - Fund the contract with ETH"
    echo -e "  ${YELLOW}snipe${NC}      - Execute a token snipe"
    echo -e "  ${YELLOW}help${NC}       - Show this help message"
}

# Command handling
case "$1" in
    setup)
        echo -e "${GREEN}Installing dependencies...${NC}"
        forge install OpenZeppelin/openzeppelin-contracts@v4.9.0 --no-commit
        forge install Uniswap/v2-periphery@master --no-commit
        echo -e "${GREEN}Dependencies installed successfully!${NC}"
        ;;
    build)
        echo -e "${GREEN}Building contracts...${NC}"
        forge build
        ;;
    test)
        echo -e "${GREEN}Running tests...${NC}"
        forge test -vvv
        ;;
    deploy)
        echo -e "${GREEN}Deploying contract to ${NETWORK}...${NC}"
        forge script script/Deploy.s.sol:DeployScript \
            --rpc-url ${!RPC_NETWORK} \
            --broadcast \
            --verify \
            -vvvv
        ;;
    fund)
        echo -e "${GREEN}Funding contract at ${CONTRACT_ADDRESS}...${NC}"
        forge script script/Fund.s.sol:FundScript \
            --rpc-url ${!RPC_NETWORK} \
            --broadcast \
            -vvvv
        ;;
    snipe)
        echo -e "${GREEN}Executing snipe for token ${TOKEN_ADDRESS}...${NC}"
        forge script script/Snipe.s.sol:SnipeScript \
            --rpc-url ${!RPC_NETWORK} \
            --broadcast \
            -vvvv
        ;;
    help)
        show_help
        ;;
    *)
        echo -e "${RED}Invalid command.${NC}"
        show_help
        exit 1
        ;;
esac
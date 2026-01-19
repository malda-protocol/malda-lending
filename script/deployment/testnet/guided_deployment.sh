#!/bin/bash

# Testnet Deployment Commands
# Complete reference for deploying Malda protocol to testnet
# 
# Prerequisites:
# 1. Update deployment-config-testnet.json with your owner address
# 2. Setup .env file with PRIVATE_KEY and RPC URLs
# 3. Ensure you have sufficient testnet ETH on all chains

set -e  # Exit on error
set -o pipefail  # Exit on error in pipeline

# Use testnet profile for Paris EVM compatibility
export FOUNDRY_PROFILE=testnet
make clean && make build

# Create logs directory if it doesn't exist
LOGS_DIR="script/deployment/testnet/logs"
mkdir -p "$LOGS_DIR"

# Timestamp for this deployment run
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=================================================="
echo "Malda Protocol Testnet Deployment"
echo "=================================================="
echo ""
echo "⚠️  IMPORTANT: Before running, ensure:"
echo "   1. Owner address updated in deployment-config-testnet.json"
echo "   2. .env file configured with PRIVATE_KEY and RPC URLs"
echo "   3. Sufficient testnet ETH on linea_sepolia, op_sepolia, sepolia"
echo "   4. Foundry profile set to testnet (echo: $(echo $FOUNDRY_PROFILE))"
echo ""

# Check for unbuffer (optional, improves progress bar display)
if ! command -v unbuffer &> /dev/null; then
    echo "💡 TIP: Install 'expect' package for better progress bar display:"
    echo "   macOS: brew install expect"
    echo "   Linux: sudo apt-get install expect"
    echo ""
fi

read -p "Press Enter to continue or Ctrl+C to abort..."

# ============================================
# STEP 1: Deploy Mock Tokens
# ============================================
echo ""
echo "=================================================="
echo "STEP 1: Deploying Mock Tokens"
echo "=================================================="
echo ""

STEP1_LOG="$LOGS_DIR/$TIMESTAMP-01_mock_tokens.log"
echo "📝 Logging output to: $STEP1_LOG"
echo ""

# Run with progress bars in terminal, clean log to file
if command -v unbuffer &> /dev/null; then
    unbuffer forge script script/deployment/testnet/DeployMockTokens.s.sol:DeployMockTokens \
        --rpc-url linea_sepolia \
        --verify \
        --broadcast 2>&1 | tee /dev/tty | sed 's/\x1b\[[0-9;]*m//g; /^## Setting up/,/^ONCHAIN EXECUTION COMPLETE/d' > "$STEP1_LOG"
else
    forge script script/deployment/testnet/DeployMockTokens.s.sol:DeployMockTokens \
        --rpc-url linea_sepolia \
        --verify \
        --broadcast 2>&1 | tee "$STEP1_LOG"
fi

echo ""
echo "✅ Mock tokens deployed!"
echo ""
echo "📝 ACTION REQUIRED:"
echo "   1. Check $STEP1_LOG for deployed addresses"
echo "   2. Note the USDC Mock address"
echo "   3. Note the wstETH Mock address"
echo "   4. Update deployment-config-testnet.json:"
echo "      - networks.(linea_sepolia|op_sepolia|sepolia).markets[0].underlying = USDC address"
echo "      - networks.(linea_sepolia|op_sepolia|sepolia).markets[1].underlying = wstETH address"
echo ""
read -p "Press Enter after updating the config file..."

# ============================================
# STEP 2: Deploy Core Infrastructure
# ============================================
echo ""
echo "=================================================="
echo "STEP 2: Deploying Core Infrastructure"
echo "=================================================="
echo ""

STEP2_LOG="$LOGS_DIR/$TIMESTAMP-02_core_infrastructure.log"
echo "📝 Logging output to: $STEP2_LOG"
echo ""

if command -v unbuffer &> /dev/null; then
    unbuffer forge script script/deployment/testnet/DeployCoreTestnet.s.sol:DeployCoreTestnet \
        --slow \
        --multi \
        --verify \
        --broadcast 2>&1 | tee /dev/tty | sed 's/\x1b\[[0-9;]*m//g; /^## Setting up/,/^ONCHAIN EXECUTION COMPLETE/d' > "$STEP2_LOG"
else
    forge script script/deployment/testnet/DeployCoreTestnet.s.sol:DeployCoreTestnet \
        --slow \
        --multi \
        --verify \
        --broadcast 2>&1 | tee "$STEP2_LOG"
fi

echo ""
echo "✅ Core infrastructure deployed!"
echo ""
echo "📝 ACTION REQUIRED:"
echo "   1. Check $STEP2_LOG for deployed addresses"
echo "   2. Update script/deployment/testnet/DeployMarketsTestnet.s.sol (lines 44-50)"
echo "      with the following addresses:"
echo "      - deployer"
echo "      - rolesContract"
echo "      - zkVerifier"
echo "      - operator"
echo "      - oracle"
echo "      - pauser"
echo "      - blacklister"
echo ""
read -p "Press Enter after updating DeployMarketsTestnet.s.sol..."

# ============================================
# STEP 3: Deploy Markets
# ============================================
echo ""
echo "=================================================="
echo "STEP 3: Deploying Markets"
echo "=================================================="
echo ""

STEP3_LOG="$LOGS_DIR/$TIMESTAMP-03_markets.log"
echo "📝 Logging output to: $STEP3_LOG"
echo ""

if command -v unbuffer &> /dev/null; then
    unbuffer forge script script/deployment/testnet/DeployMarketsTestnet.s.sol:DeployMarketsTestnet \
        --slow \
        --multi \
        --verify \
        --broadcast 2>&1 | tee /dev/tty | sed 's/\x1b\[[0-9;]*m//g; /^## Setting up/,/^ONCHAIN EXECUTION COMPLETE/d' > "$STEP3_LOG"
else
    forge script script/deployment/testnet/DeployMarketsTestnet.s.sol:DeployMarketsTestnet \
        --slow \
        --multi \
        --verify \
        --broadcast 2>&1 | tee "$STEP3_LOG"
fi

echo ""
echo "✅ Markets deployed!"
echo ""
echo "📝 ACTION REQUIRED:"
echo "   1. Check $STEP3_LOG for deployed addresses"
echo "   2. Update script/deployment/testnet/ConfigureTestnet.s.sol:"
echo "      - Lines 91-96: Core addresses (same as DeployMarketsTestnet)"
echo "      - Lines 100-101: Market addresses (HOST proxy addresses only)"
echo "        marketAddresses.push(address(<mUSDCMock HOST proxy address>));"
echo "        marketAddresses.push(address(<mwstETHMock HOST proxy address>));"
echo ""
read -p "Press Enter after updating ConfigureTestnet.s.sol..."

# ============================================
# STEP 4: Configure Protocol
# ============================================
echo ""
echo "=================================================="
echo "STEP 4: Configuring Protocol"
echo "=================================================="
echo ""

STEP4_LOG="$LOGS_DIR/$TIMESTAMP-04_configuration.log"
echo "📝 Logging output to: $STEP4_LOG"
echo ""

if command -v unbuffer &> /dev/null; then
    unbuffer forge script script/deployment/testnet/ConfigureTestnet.s.sol:ConfigureTestnet \
        --slow \
        --multi \
        --broadcast 2>&1 | tee /dev/tty | sed 's/\x1b\[[0-9;]*m//g; /^## Setting up/,/^ONCHAIN EXECUTION COMPLETE/d' > "$STEP4_LOG"
else
    forge script script/deployment/testnet/ConfigureTestnet.s.sol:ConfigureTestnet \
        --slow \
        --multi \
        --broadcast 2>&1 | tee "$STEP4_LOG"
fi

echo ""
echo "✅ Protocol configured!"
echo ""

# ============================================
# DEPLOYMENT COMPLETE
# ============================================
echo ""
echo "=================================================="
echo "🎉 DEPLOYMENT COMPLETE!"
echo "=================================================="
echo ""
echo "✅ All contracts deployed and configured"
echo ""
echo "📂 Deployment logs saved to:"
echo "   - $STEP1_LOG"
echo "   - $STEP2_LOG"
echo "   - $STEP3_LOG"
echo "   - $STEP4_LOG"
echo ""
echo "📋 Next Steps:"
echo "   1. Update malda-config repository with deployed addresses"
echo "   2. Test basic functionality:"
echo "      - Mint mock tokens"
echo "      - Supply to markets"
echo "      - Borrow from markets"
echo "   3. Document all deployed addresses"
echo "=================================================="

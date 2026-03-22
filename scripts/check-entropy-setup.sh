#!/usr/bin/env bash
#
# Pyth Entropy v2 — Setup Validation Script
#
# Checks that the project is properly configured for Entropy integration.
# Run from the project root directory.
#
# Usage: bash check-entropy-setup.sh
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
WARN=0
FAIL=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; ((PASS++)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; ((WARN++)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ((FAIL++)); }

echo "═══════════════════════════════════════════════════"
echo "  Pyth Entropy v2 — Setup Checker"
echo "═══════════════════════════════════════════════════"
echo ""

# ─── Detect Framework ──────────────────────────────────────

echo "1. Smart Contract Framework"

if [ -f "foundry.toml" ]; then
    pass "Foundry detected (foundry.toml)"
    FRAMEWORK="foundry"
elif [ -f "hardhat.config.ts" ] || [ -f "hardhat.config.js" ]; then
    pass "Hardhat detected"
    FRAMEWORK="hardhat"
elif [ -f "truffle-config.js" ]; then
    pass "Truffle detected"
    FRAMEWORK="truffle"
else
    warn "No smart contract framework detected (foundry.toml / hardhat.config / truffle-config)"
    FRAMEWORK="none"
fi

# ─── Check SDK Installation ────────────────────────────────

echo ""
echo "2. Entropy SDK"

if [ -d "node_modules/@pythnetwork/entropy-sdk-solidity" ]; then
    pass "SDK installed: @pythnetwork/entropy-sdk-solidity"
    
    # Check for ABI files
    if [ -f "node_modules/@pythnetwork/entropy-sdk-solidity/abis/IEntropyV2.json" ]; then
        pass "ABI file found: IEntropyV2.json"
    else
        warn "ABI file not found (may be older SDK version)"
    fi
else
    fail "SDK not installed. Run: npm install @pythnetwork/entropy-sdk-solidity"
fi

# ─── Check Remappings (Foundry) ────────────────────────────

echo ""
echo "3. Import Configuration"

if [ "$FRAMEWORK" = "foundry" ]; then
    if [ -f "remappings.txt" ]; then
        if grep -q "@pythnetwork/entropy-sdk-solidity" remappings.txt 2>/dev/null; then
            pass "Foundry remapping configured"
        else
            fail "Missing remapping. Add to remappings.txt:"
            echo "     @pythnetwork/entropy-sdk-solidity/=node_modules/@pythnetwork/entropy-sdk-solidity"
        fi
    else
        fail "No remappings.txt found. Create it with:"
        echo "     @pythnetwork/entropy-sdk-solidity/=node_modules/@pythnetwork/entropy-sdk-solidity"
    fi
elif [ "$FRAMEWORK" = "hardhat" ]; then
    pass "Hardhat resolves node_modules imports automatically"
fi

# ─── Check for Solidity Contracts Using Entropy ─────────────

echo ""
echo "4. Contract Integration"

if command -v grep &>/dev/null; then
    CONSUMER_FILES=$(grep -rl "IEntropyConsumer" --include="*.sol" . 2>/dev/null || true)
    if [ -n "$CONSUMER_FILES" ]; then
        pass "Found IEntropyConsumer implementations:"
        echo "$CONSUMER_FILES" | while read -r f; do echo "     $f"; done
    else
        warn "No contracts implementing IEntropyConsumer found"
    fi

    ENTROPY_V2_FILES=$(grep -rl "IEntropyV2" --include="*.sol" . 2>/dev/null || true)
    if [ -n "$ENTROPY_V2_FILES" ]; then
        pass "Found IEntropyV2 usage"
    else
        warn "No contracts using IEntropyV2 found"
    fi

    # Check for v1 usage (should migrate)
    V1_FILES=$(grep -rl "IEntropy\b" --include="*.sol" . 2>/dev/null | grep -v "IEntropyV2" | grep -v "IEntropyConsumer" | grep -v "node_modules" || true)
    if [ -n "$V1_FILES" ]; then
        warn "Found Entropy v1 usage (consider migrating to v2):"
        echo "$V1_FILES" | while read -r f; do echo "     $f"; done
    fi

    # Check callback implementation
    CALLBACK_FILES=$(grep -rl "entropyCallback" --include="*.sol" . 2>/dev/null | grep -v "node_modules" || true)
    if [ -n "$CALLBACK_FILES" ]; then
        pass "Found entropyCallback implementations"
        
        # Warn about potential reverts in callback
        for f in $CALLBACK_FILES; do
            if grep -q "require(" "$f" 2>/dev/null; then
                warn "File $f has require() in callback — ensure it cannot revert"
            fi
        done
    else
        warn "No entropyCallback implementations found"
    fi
fi

# ─── Check Off-Chain Dependencies ───────────────────────────

echo ""
echo "5. Off-Chain Libraries"

if [ -f "package.json" ]; then
    if grep -q '"ethers"' package.json 2>/dev/null; then
        pass "ethers.js detected"
    fi
    if grep -q '"viem"' package.json 2>/dev/null; then
        pass "viem detected"
    fi
    if grep -q '"web3"' package.json 2>/dev/null; then
        pass "web3.js detected"
    fi
fi

if [ -f "requirements.txt" ]; then
    if grep -q "web3" requirements.txt 2>/dev/null; then
        pass "web3.py detected"
    fi
fi

# ─── Check Environment ─────────────────────────────────────

echo ""
echo "6. Environment"

if [ -f ".env" ] || [ -f ".env.local" ]; then
    ENV_FILE=$([ -f ".env.local" ] && echo ".env.local" || echo ".env")
    
    if grep -q "RPC_URL" "$ENV_FILE" 2>/dev/null; then
        pass "RPC_URL configured"
    else
        warn "No RPC_URL in $ENV_FILE"
    fi
    
    if grep -q "PRIVATE_KEY" "$ENV_FILE" 2>/dev/null; then
        pass "PRIVATE_KEY configured"
    else
        warn "No PRIVATE_KEY in $ENV_FILE"
    fi
    
    if grep -q "ENTROPY_ADDRESS" "$ENV_FILE" 2>/dev/null; then
        pass "ENTROPY_ADDRESS configured"
    else
        warn "No ENTROPY_ADDRESS in $ENV_FILE — see chainlist for your chain's address"
    fi
else
    warn "No .env file found"
fi

# ─── Check Foundry Installation ─────────────────────────────

echo ""
echo "7. Tooling"

if command -v forge &>/dev/null; then
    FORGE_VERSION=$(forge --version 2>/dev/null | head -1)
    pass "Foundry installed: $FORGE_VERSION"
else
    if [ "$FRAMEWORK" = "foundry" ]; then
        fail "Foundry not installed but foundry.toml exists. Install: https://book.getfoundry.sh/getting-started/installation"
    else
        warn "Foundry not installed (optional if using Hardhat/Truffle)"
    fi
fi

if command -v node &>/dev/null; then
    NODE_VERSION=$(node --version)
    pass "Node.js installed: $NODE_VERSION"
else
    fail "Node.js not installed. Required for SDK. Install: https://nodejs.org"
fi

# ─── Summary ────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${YELLOW}${WARN} warnings${NC}, ${RED}${FAIL} failed${NC}"
echo "═══════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Fix the failed checks above before proceeding."
    exit 1
fi

if [ "$WARN" -gt 0 ]; then
    echo ""
    echo "Warnings are informational — address them if relevant to your setup."
fi

echo ""
echo "Ready to integrate Pyth Entropy v2!"

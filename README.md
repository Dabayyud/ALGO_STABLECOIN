# DecenSC (DSC) - Decentralized Stablecoin Protocol

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.19-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-000000)](https://getfoundry.sh/)

> A decentralized, overcollateralized stablecoin protocol anchored to the USD, designed with MakerDAO-inspired architecture and advanced security measures.

## 🏗️ Architecture Overview

DecenSC is an **Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized** low volatility stablecoin with the following characteristics:

- **Collateral**: Wrapped Ethereum (wETH) and Wrapped Bitcoin (wBTC)
- **Stability Mechanism**: Algorithmic overcollateralization
- **Price Oracle**: Chainlink price feeds with staleness protection
- **Governance**: Decentralized engine-controlled minting/burning

## 🚀 Key Features

### 🔒 **Overcollateralization System**
- Minimum 150% collateralization ratio enforced at all times
- Real-time collateral valuation using Chainlink oracles
- Automatic liquidation mechanism for undercollateralized positions

### ⚡ **Liquidation Engine** 
- 15% liquidation bonus for liquidators
- Partial liquidation support to restore healthy ratios
- Protection against cascading liquidations

### 🛡️ **Oracle Security**
- Chainlink price feed integration with staleness checks
- 1-hour staleness threshold protection
- Fallback mechanisms for price feed failures

### 🧪 **Advanced Testing Suite**
- Comprehensive unit tests
- Fuzz testing with 1000+ runs
- Invariant testing with 1280 runs at 128 depth
- Property-based testing for protocol invariants

## 📋 Protocol Specifications

| Parameter | Value |
|-----------|--------|
| **Minimum Collateralization Ratio** | 150% |
| **Liquidation Bonus** | 15% |
| **Supported Collateral** | wETH, wBTC |
| **Price Oracle** | Chainlink (1-hour staleness protection) |
| **Target Peg** | $1.00 USD |

## 🏛️ Smart Contract Architecture

### Core Contracts

#### 1. DecenSC.sol
- **Type**: ERC20 Token Contract
- **Functions**: 
  - Standard ERC20 functionality
  - Owner-controlled minting and burning
  - Balance validation for burn operations
  
#### 2. DecenSCEngine.sol  
- **Type**: Protocol Engine & Logic Controller
- **Key Functions**:
  - `depositCollateralAndMintDSC()` - Combined collateral deposit and DSC minting
  - `redeemCollateralForDSC()` - Combined DSC burning and collateral redemption
  - `liquidate()` - Liquidation mechanism with bonus rewards
  - `_getCollateralizationRatio()` - Real-time collateral ratio calculation
  
#### 3. OracleLib.sol
- **Type**: Oracle Safety Library
- **Functions**:
  - Staleness protection for Chainlink feeds
  - Price data validation and formatting

## 🔐 Security Measures

### **Reentrancy Protection**
- All external functions protected with OpenZeppelin's `ReentrancyGuard`
- CEI (Checks-Effects-Interactions) pattern implementation

### **Oracle Manipulation Resistance** 
- Chainlink decentralized price feeds
- Built-in staleness detection (1-hour threshold)
- Price feed validation before execution

### **Access Controls**
- Owner-only minting and burning for DSC token
- Engine-controlled token operations
- Immutable critical parameters

### **Economic Security**
- 150% minimum collateralization enforces protocol solvency
- Liquidation incentives maintain healthy ecosystem
- No algorithmic rebalancing reduces systemic risk

## 📊 Protocol Invariants

The protocol maintains the following critical invariants:

1. **Global Overcollateralization**: Protocol must always be overcollateralized
2. **Individual Ratio Enforcement**: Every user must maintain minimum 150% collateralization
3. **Token Conservation**: Total DSC minted equals sum of all user balances  
4. **Collateral Accounting**: Engine's collateral balances equal all user deposits

## 🛠️ Development Setup

### Prerequisites
- [Foundry](https://getfoundry.sh/) installed
- Git for version control
- Code editor (VS Code recommended)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd DeFi_STABLECOIN

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test

# Run with verbosity for detailed output
forge test -vvvv
```

### Testing Suites

```bash
# Run unit tests
forge test --match-path test/unit/*

# Run fuzz tests  
forge test --match-path test/Fuzz/*

# Run invariant tests
forge test --match-path test/Fuzz/Invariance.t.sol

# Generate gas report
forge test --gas-report

# Check coverage
forge coverage
```

## 🚀 Deployment

### Local Deployment

```bash
# Start local anvil chain
anvil

# Deploy to local testnet
forge script script/DeployDSC.s.sol:DeployDSC --rpc-url http://localhost:8545 --broadcast
```

### Testnet Deployment

```bash
# Deploy to Sepolia testnet (example)
forge script script/DeployDSC.s.sol:DeployDSC \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

## 📝 Usage Examples

### For Users

#### Deposit Collateral and Mint DSC
```solidity
// Approve wETH spending
wETH.approve(address(dscEngine), 2 ether);

// Deposit 2 ETH and mint 1000 DSC (assuming ETH = $1500)
// Results in 300% collateralization ratio
dscEngine.depositCollateralAndMintDSC(
    address(wETH),
    2 ether,        // $3000 worth of collateral
    1000 ether      // $1000 worth of DSC
);
```

#### Check Collateralization Status
```solidity
uint256 ratio = dscEngine._getCollateralizationRatio(userAddress);
// ratio = 300 (representing 300%)
```

### For Liquidators

#### Liquidate Undercollateralized Position  
```solidity
// Liquidate user's position, paying off 500 DSC debt
dscEngine.liquidate(
    address(wETH),     // Collateral to seize
    userAddress,       // User to liquidate  
    500 ether         // DSC debt to pay off
);
// Liquidator receives collateral + 15% bonus
```

## 🧪 Advanced Testing Features

### Fuzz Testing Configuration
```toml
[fuzz]
runs = 1000
max_test_rejects = 65536
seed = '0x123'
```

### Invariant Testing
The protocol includes sophisticated invariant tests that verify:
- Protocol always remains overcollateralized
- User balances consistency  
- Collateral accounting accuracy
- Oracle price bounds

### Property-Based Testing
- Handler-based testing for complex interaction scenarios
- State machine verification
- Edge case exploration through randomized inputs

## 📚 Mathematical Foundations

### Collateralization Ratio Calculation
```
Collateralization Ratio = (Total Collateral Value in USD × 100) / Total DSC Minted

Example:
- Collateral: 2 ETH @ $1,500 = $3,000
- DSC Minted: $1,000
- Ratio: (3000 × 100) / 1000 = 300%
```

### Liquidation Mechanics
```
Liquidation Threshold: 150%
Liquidation Bonus: 15%

If User Ratio < 150%:
  Liquidator pays: X DSC
  Liquidator receives: (X / ETH_Price) × 1.15 ETH
```

## 🎯 Roadmap & Future Enhancements

- [ ] Multi-collateral support expansion (SOL, LINK, etc.)
- [ ] Governance token integration  
- [ ] Flash loan functionality
- [ ] Layer 2 deployment optimization
- [ ] Advanced liquidation strategies
- [ ] Yield farming integration

## ⚠️ Risks & Disclaimers

- **Smart Contract Risk**: Code has not been formally audited
- **Oracle Risk**: Dependent on Chainlink price feed reliability  
- **Liquidation Risk**: Users must maintain adequate collateralization
- **Market Risk**: Collateral value volatility affects protocol stability

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📞 Contact & Support

For questions, suggestions, or support:
- Create an issue in this repository
- Follow best practices for DeFi protocol interaction
- Always test on testnets before mainnet deployment

---

**⚠️ Important**: This is experimental software. Use at your own risk. Always conduct thorough testing and consider professional audits before mainnet deployment.
5) Users under 150% ratio must be liquidatable.
6) Price feeds should always return postive values.
7) Liquidators should always recieve exactly 15% bonus.
8) DSC tokes should always be owned by engine.
9) Only engine should be able to mint/burn.
10) Only approved tokens should return a price feed.
11) No function should accept zero amount.
12) All state-changing function should be protected from re-entrancy.
13) Price calculations should maintain 18 decimal points precision.
14) Collateralization ratio should be calculated correctly.
15) Contract should handle type(uint256).max values appropriately.
16) Contract should work correctly with no users/collateral.
17) Getter functions should never revert.


This was by far the hardest and the most time consuming project i have ever done so far.

THE MAJOR ISSUE OF THIS PROTOCOL IS IF THE PRICE OF THE COLLATERAL FALLS DRAMATICALLY UNDER
THE COLLATERALIZATION RATIO WITHIN A BLOCK. INSOLVENCY WILL OCCUR. 


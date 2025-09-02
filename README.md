# TokenAI Platform

A decentralized AI platform built on BNB Smart Chain featuring ERC20 platform tokens and ERC1155 usage credits for AI model access.

## 🌟 Features

- **TokenAI (ERC20)**: Platform native token used for fees and treasury operations
- **LLMBits (ERC1155)**: Usage credits for AI models with configurable parameters
- **Custodial System**: Owner-controlled transfers and trades for platform management
- **Dual Fee Modes**: Pay fees in native tokens (TokenAI) or in-kind (LLMBits)
- **Expirable Tokens**: Automatic token expiration with burn-and-remint functionality
- **Trading System**: Token-to-token trading with flexible fee structures
- **Security Features**: Reentrancy protection, pausable functions, role-based access

## 🏗️ Architecture

### TokenAI Contract
- **Standard**: ERC20 with extensions
- **Features**: Mintable, Burnable, Pausable, Role-based minting
- **Symbol**: APT (mainnet) / tAPT (testnet)
- **Supply**: Dynamic (minted as needed)

### LLMBits Contract  
- **Standard**: ERC1155 with custom extensions
- **Token Types**: Configurable by model, scope, expiration, tradability
- **Operations**: Mint, transfer, trade, batch operations
- **Fee Collection**: Automatic treasury collection

## 🚀 Deployment

### Prerequisites

1. **Install Foundry**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Clone Repository**
   ```bash
   git clone git@github.com:taulanti/TokenAI.git
   cd TokenAI
   ```

3. **Install Dependencies**
   ```bash
   forge install
   ```

4. **Environment Setup**
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

### Deploy to Testnet

1. **Deploy TokenAI**
   ```bash
   forge script script/DeployTokenAI.s.sol:DeployTokenAITestnet \
     --rpc-url $BNB_TESTNET_RPC_URL --broadcast --verify
   ```

2. **Update .env with TokenAI address**
   ```bash
   TREASURY_ADDRESS=0xYourTokenAIAddress
   ```

3. **Deploy LLMBits**
   ```bash
   forge script script/DeployLLMBits.s.sol:DeployLLMBitsTestnet \
     --rpc-url $BNB_TESTNET_RPC_URL --broadcast --verify
   ```

### Deploy to Mainnet

Use the same process with mainnet scripts:
- `DeployTokenAI.s.sol:DeployTokenAI`
- `DeployLLMBits.s.sol:DeployLLMBits`

## 🧪 Testing

### Run Test Suite

```bash
# Run all tests
forge test

# Run specific test files
forge test --match-path test/TokenAI.t.sol
forge test --match-path test/LLMBits.t.sol
forge test --match-path test/Integration.t.sol
forge test --match-path test/EdgeCases.t.sol
```

### Test Coverage

```bash
forge coverage
```

### Integration Testing

```bash
# Mint test tokens
forge script script/MintTestTokens.s.sol:MintTestTokens \
  --rpc-url $BNB_TESTNET_RPC_URL --broadcast

# Test transfers
forge script script/TestTransfers.s.sol:TestTransfers \
  --rpc-url $BNB_TESTNET_RPC_URL --broadcast

# Test trading
forge script script/TestTrading.s.sol:TestTrading \
  --rpc-url $BNB_TESTNET_RPC_URL --broadcast
```

## 📋 Contract Addresses

### BNB Smart Chain Testnet
- **TokenAI**: `0x25d8d91C2C85d47b76Ab7868588F92B5933e1213`
- **LLMBits**: `0x5A270fC84b879F91469b755991f4452A13d505D9`

### Verification Links
- [TokenAI on BSCScan Testnet](https://testnet.bscscan.com/address/0x25d8d91c2c85d47b76ab7868588f92b5933e1213)
- [LLMBits on BSCScan Testnet](https://testnet.bscscan.com/address/0x5a270fc84b879f91469b755991f4452a13d505d9)

## 🔧 Configuration

### Environment Variables

```bash
# Deployment
PRIVATE_KEY=0xYourPrivateKey
BNB_RPC_URL=https://bsc-dataseed1.binance.org/
BNB_TESTNET_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545/
BSCSCAN_API_KEY=YourBSCScanAPIKey

# Contract Addresses
TREASURY_ADDRESS=0xTokenAIAddress
TOKEN_AI_ADDRESS=0xTokenAIAddress  
LLM_BITS_ADDRESS=0xLLMBitsAddress

# Testing
TEST_ACCOUNT_1_ADDRESS=0xTestAddress1
TEST_ACCOUNT_2_ADDRESS=0xTestAddress2
```

## 🛡️ Security

### Implemented Protections
- ✅ **Reentrancy Guards**: Critical functions protected
- ✅ **Access Control**: Owner-only operations with role-based minting
- ✅ **Pausable**: Emergency pause functionality
- ✅ **Input Validation**: Comprehensive parameter checking
- ✅ **Overflow Protection**: Solidity 0.8+ automatic checks
- ✅ **Fee Validation**: Prevents excessive fee attacks

### Audit Status
- **Test Coverage**: 91 tests passing
- **Edge Cases**: Comprehensive security testing included
- **Gas Optimization**: Batch operations and consolidated calls

## 📖 Documentation

- [Deployment Guide](script/README.md)
- [Contract Architecture](src/)
- [Test Documentation](test/)
- [Security Analysis](test/EdgeCases.t.sol)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🌐 Networks

### BNB Smart Chain Mainnet
- **Chain ID**: 56
- **RPC**: https://bsc-dataseed1.binance.org/
- **Explorer**: https://bscscan.com

### BNB Smart Chain Testnet  
- **Chain ID**: 97
- **RPC**: https://data-seed-prebsc-1-s1.binance.org:8545/
- **Explorer**: https://testnet.bscscan.com
- **Faucet**: https://testnet.bnbchain.org/faucet-smart

## 📞 Support

For questions and support:
- Create an issue in this repository
- Review the [troubleshooting guide](script/README.md#troubleshooting)

---

**Built with ❤️ using [Foundry](https://getfoundry.sh/)**
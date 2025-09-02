# Deployment and Testing Scripts

This directory contains deployment scripts and testing utilities for the TokenAI platform contracts.

## BNB Smart Chain Deployment

### Prerequisites

1. **Environment Setup**
   ```bash
   cp .env.example .env
   # Edit .env with your actual values
   ```

2. **Required Environment Variables**
   - `PRIVATE_KEY`: Deployer wallet private key (with 0x prefix)
   - `BNB_RPC_URL`: BNB Smart Chain RPC endpoint
   - `BNB_TESTNET_RPC_URL`: BNB Smart Chain Testnet RPC endpoint
   - `BSCSCAN_API_KEY`: BSCScan API key for verification
   - `TREASURY_ADDRESS`: Treasury address (TokenAI contract address)

### Deployment Process

#### 1. Deploy TokenAI (Step 1)

**Testnet:**
```bash
forge script script/DeployTokenAI.s.sol:DeployTokenAITestnet \
  --rpc-url $BNB_TESTNET_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $BSCSCAN_API_KEY
```

**Mainnet:**
```bash
forge script script/DeployTokenAI.s.sol:DeployTokenAI \
  --rpc-url $BNB_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $BSCSCAN_API_KEY
```

#### 2. Update .env File

After TokenAI deployment, add the contract address to your `.env`:
```bash
TREASURY_ADDRESS=0xYourTokenAIAddress
```

#### 3. Deploy LLMBits (Step 2)

**Testnet:**
```bash
forge script script/DeployLLMBits.s.sol:DeployLLMBitsTestnet \
  --rpc-url $BNB_TESTNET_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $BSCSCAN_API_KEY
```

**Mainnet:**
```bash
forge script script/DeployLLMBits.s.sol:DeployLLMBits \
  --rpc-url $BNB_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $BSCSCAN_API_KEY
```

### Testing Scripts

After deployment, use these scripts to test functionality:

#### Mint Test Tokens

```bash
# Add test account addresses to .env first:
TEST_ACCOUNT_1_ADDRESS=0xYourTestAddress1
TEST_ACCOUNT_2_ADDRESS=0xYourTestAddress2

# Mint test tokens
forge script script/MintTestTokens.s.sol:MintTestTokens \
  --rpc-url $BNB_TESTNET_RPC_URL \
  --broadcast
```

This script will:
- Mint 1000 tAPT to each test account for fees
- Create various LLMBits token types (tradable/non-tradable)
- Distribute tokens for testing trading and transfers

#### Test Transfer Functionality

```bash
forge script script/TestTransfers.s.sol:TestTransfers \
  --rpc-url $BNB_TESTNET_RPC_URL \
  --broadcast
```

Tests:
- Simple transfers with native fees (tAPT)
- Transfers with in-kind fees (LLMBits tokens)
- Batch transfers to multiple recipients
- Non-tradable token restrictions
- Origin pool transfer permissions

#### Test Trading Functionality

```bash
forge script script/TestTrading.s.sol:TestTrading \
  --rpc-url $BNB_TESTNET_RPC_URL \
  --broadcast
```

Tests:
- Token-to-token trading with native fees
- Token-to-token trading with in-kind fees
- Treasury fee collection
- Cross-course token exchanges

### Contract Addresses (Testnet)

**Current Testnet Deployment:**
- **TokenAI**: `0x25d8d91C2C85d47b76Ab7868588F92B5933e1213`
- **LLMBits**: `0x5A270fC84b879F91469b755991f4452A13d505D9`
- **Treasury**: Same as TokenAI address

**Verification:**
- TokenAI: https://testnet.bscscan.com/address/0x25d8d91c2c85d47b76ab7868588f92b5933e1213
- LLMBits: https://testnet.bscscan.com/address/0x5a270fc84b879f91469b755991f4452a13d505d9

### Contract Configuration

#### TokenAI Settings
- **Name**: AI Platform Token (Testnet)
- **Symbol**: tAPT
- **Initial Supply**: 0 (tokens minted as needed)
- **Decimals**: 18
- **Features**: Mintable, Burnable, Pausable, Role-based access

#### LLMBits Settings
- **Base URI**: `https://testnet-api.tokenai.com/metadata/`
- **Treasury**: TokenAI contract address
- **Features**: ERC1155, Custodial transfers, Dual fee modes, Expirable tokens

### Security Features

✅ **Access Control**: Owner-only operations, Role-based minting
✅ **Reentrancy Protection**: ReentrancyGuard on critical functions
✅ **Pausable**: Emergency pause functionality
✅ **Fee Collection**: Automatic treasury collection
✅ **Token Expiration**: Automatic expiry handling
✅ **Trade Restrictions**: Non-tradable token support

### Useful Commands

```bash
# Check deployer balance
cast balance $DEPLOYER_ADDRESS --rpc-url $BNB_TESTNET_RPC_URL

# Check TokenAI contract
cast call $TOKEN_AI_ADDRESS "name()" --rpc-url $BNB_TESTNET_RPC_URL
cast call $TOKEN_AI_ADDRESS "totalSupply()" --rpc-url $BNB_TESTNET_RPC_URL

# Check LLMBits contract
cast call $LLM_BITS_ADDRESS "treasury()" --rpc-url $BNB_TESTNET_RPC_URL
cast call $TOKEN_AI_ADDRESS "minters(address)" $LLM_BITS_ADDRESS --rpc-url $BNB_TESTNET_RPC_URL

# Check user balances
cast call $TOKEN_AI_ADDRESS "balanceOf(address)" $TEST_ACCOUNT_1_ADDRESS --rpc-url $BNB_TESTNET_RPC_URL
```

### Network Information

#### BNB Smart Chain Testnet
- **Chain ID**: 97
- **Currency**: tBNB
- **Explorer**: https://testnet.bscscan.com
- **RPC**: https://data-seed-prebsc-1-s1.binance.org:8545/
- **Faucet**: https://testnet.bnbchain.org/faucet-smart

#### BNB Smart Chain Mainnet
- **Chain ID**: 56
- **Currency**: BNB
- **Explorer**: https://bscscan.com
- **RPC**: https://bsc-dataseed1.binance.org/

### Troubleshooting

1. **Insufficient Balance**: Get tBNB from the testnet faucet
2. **Private Key Format**: Ensure private key has "0x" prefix
3. **Gas Issues**: Current gas price is ~0.1 gwei on testnet
4. **Verification Failures**: Check constructor arguments match deployment

### Next Steps

1. **Test on Testnet**: Use testing scripts to verify functionality
2. **Deploy to Mainnet**: Use same process with mainnet RPC
3. **Frontend Integration**: Connect your dApp to deployed contracts
4. **Production Setup**: Configure treasury, additional minters, etc.
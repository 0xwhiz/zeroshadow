# AAVE Liquidation Monitoring Bot

A comprehensive monitoring bot that detects liquidation opportunities on AAVE V3 and sends Telegram alerts. The bot scans new blocks and AAVE interactions to identify users whose positions can be liquidated.

## Features

- 🔍 **Real-time Monitoring**: Scans every new block for AAVE interactions
- 🚨 **Telegram Alerts**: Sends immediate notifications when liquidation opportunities are detected
- 📊 **Health Factor Tracking**: Monitors user health factors and debt positions
- 🧪 **Comprehensive Testing**: Foundry test suite with historical data scenarios
- ⚡ **Configurable**: Adjustable minimum liquidation amounts and alert thresholds

## Architecture

### Smart Contract (`AAVELiquidationBot.sol`)
- Interfaces with AAVE V3 Pool and PoolDataProvider
- Calculates liquidation opportunities
- Emits events for detected opportunities
- Configurable Telegram bot settings

### Node.js Monitor (`scripts/monitor.js`)
- Listens to new blocks via WebSocket
- Parses AAVE-related transactions
- Sends Telegram alerts via API
- Handles historical data processing

### Foundry Tests (`test/AAVELiquidationBot.t.sol`)
- Comprehensive test coverage
- Mock AAVE pool interactions
- Time-specific liquidation scenarios
- Multiple user simulation

## Installation

### Prerequisites
- Node.js 16+
- Foundry
- Telegram Bot Token
- Ethereum RPC endpoint

### Setup

1. **Clone and Install Dependencies**
```bash
git clone <repository>
cd aave-liquidation-bot
npm install
```

2. **Install Foundry Dependencies**
```bash
forge install
```

3. **Configure Environment**
```bash
cp env.example .env
# Edit .env with your configuration
```

4. **Build Contracts**
```bash
forge build
```

## Configuration

### Environment Variables

Create a `.env` file with the following variables:

```env
# Ethereum RPC Configuration
RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_API_KEY
PRIVATE_KEY=your_private_key_here

# AAVE V3 Contract Addresses (Ethereum Mainnet)
AAVE_POOL_ADDRESS=0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf
AAVE_POOL_DATA_PROVIDER_ADDRESS=0x7Bd3d02c3c478147643e1372c4565d5bF564d206

# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN=your_telegram_bot_token_here
TELEGRAM_CHAT_ID=your_chat_id_here

# Bot Configuration
BOT_ADDRESS=deployed_bot_contract_address_here
MIN_LIQUIDATION_AMOUNT=1000000000000000000000

# Monitoring Configuration
START_BLOCK=latest
BLOCK_INTERVAL=1
```

### Telegram Bot Setup

1. Create a Telegram bot via [@BotFather](https://t.me/botfather)
2. Get your bot token
3. Get your chat ID by messaging the bot and checking: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`

## Usage

### Deploy the Smart Contract

```bash
# Deploy to mainnet
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# Deploy to testnet
forge script script/Deploy.s.sol --rpc-url $TESTNET_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Run the Monitor

```bash
# Start monitoring
npm start

# Or run directly
node scripts/monitor.js
```

### Run Tests

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test test_LiquidationAtSpecificTime

# Run with verbose output
forge test -vvv
```

## Test Cases

The test suite includes comprehensive scenarios:

### Basic Functionality
- Constructor validation
- Configuration updates
- Block processing
- User liquidation checks

### Liquidation Scenarios
- Users who can be liquidated
- Users who cannot be liquidated
- Minimum amount filtering
- Multiple user scenarios

### Time-Specific Tests
- Liquidation at specific timestamps
- Historical data processing
- Block-by-block monitoring

### Example Test: Liquidation at Specific Time

```solidity
function test_LiquidationAtSpecificTime() public {
    // Set a specific timestamp
    uint256 specificTime = 1640995200; // January 1, 2022
    vm.warp(specificTime);
    
    // Mock user data indicating liquidation possibility
    vm.mockCall(
        MOCK_POOL,
        abi.encodeWithSignature("getUserAccountData(address)"),
        abi.encode(
            1000e18, // totalCollateralBase
            2000e18, // totalDebtBase
            0,       // availableBorrowsBase
            8000,    // currentLiquidationThreshold
            7500,    // ltv
            5e17     // healthFactor (0.5, below 1.0 threshold)
        )
    );
    
    uint256 debtToCover = 1500e18;
    
    // Expect liquidation opportunity event
    vm.expectEmit(true, true, true, true);
    emit LiquidationOpportunityDetected(
        MOCK_USER,
        MOCK_ASSET,
        debtToCover,
        debtToCover * 110 / 100,
        specificTime
    );
    
    bot.simulateLiquidation(MOCK_USER, MOCK_ASSET, debtToCover);
}
```

## Telegram Alert Format

The bot sends formatted alerts like this:

```
🚨 LIQUIDATION OPPORTUNITY DETECTED!

👤 User: 0x1234567890123456789012345678901234567890
💰 Total Debt: 2000.0 USD
🏦 Total Collateral: 1000.0 USD
⚡ Health Factor: 0.5
🔗 Transaction: 0xabcdef1234567890abcdef1234567890abcdef12

⏰ Time: 2024-01-01T12:00:00.000Z
```

## Monitoring Features

### Block Processing
- Scans every new block for AAVE interactions
- Tracks processed blocks to avoid duplicates
- Handles network reorgs gracefully

### Transaction Analysis
- Identifies AAVE pool interactions
- Extracts user addresses from transactions
- Calculates liquidation opportunities

### Alert System
- Configurable minimum amounts
- Rate limiting to prevent spam
- Error handling and retry logic

## Security Considerations

- **Private Key Security**: Never commit private keys to version control
- **RPC Rate Limits**: Use reliable RPC providers with sufficient rate limits
- **Telegram Bot Security**: Keep bot tokens secure
- **Gas Optimization**: Monitor gas costs for contract interactions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For issues and questions:
- Create an issue on GitHub
- Check the test files for usage examples
- Review the AAVE V3 documentation

## Disclaimer

This bot is for educational and monitoring purposes. Always verify liquidation opportunities before acting on them. The authors are not responsible for any financial losses incurred through the use of this software.

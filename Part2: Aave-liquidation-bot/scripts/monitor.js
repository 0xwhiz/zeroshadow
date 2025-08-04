const { ethers } = require('ethers');
const axios = require('axios');
require('dotenv').config();

class AAVELiquidationMonitor {
    constructor() {
        this.provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
        this.bot = new ethers.Contract(
            process.env.BOT_ADDRESS,
            require('../artifacts/AAVELiquidationBot.json').abi,
            this.provider
        );
        this.lastProcessedBlock = 0;
    }

    async sendTelegramAlert(message) {
        const url = `https://api.telegram.org/bot${process.env.TELEGRAM_BOT_TOKEN}/sendMessage`;
        const data = {
            chat_id: process.env.TELEGRAM_CHAT_ID,
            text: message,
            parse_mode: 'HTML'
        };

        try {
            await axios.post(url, data);
            console.log('Telegram alert sent successfully');
        } catch (error) {
            console.error('Failed to send Telegram alert:', error.message);
        }
    }

    async checkUserLiquidation(userAddress) {
        try {
            const result = await this.bot.checkUserLiquidation(userAddress);
            return {
                canBeLiquidated: result[0],
                totalDebtBase: result[1],
                availableBorrowsBase: result[2],
                totalCollateralBase: result[3],
                healthFactor: result[4]
            };
        } catch (error) {
            console.error(`Error checking liquidation for ${userAddress}:`, error.message);
            return null;
        }
    }

    async processBlock(blockNumber) {
        console.log(`Processing block ${blockNumber}...`);
        
        try {
            // Get block transactions
            const block = await this.provider.getBlock(blockNumber, true);
            
            // Check for AAVE interactions
            for (const tx of block.transactions) {
                if (tx.to && this.isAAVEInteraction(tx.to)) {
                    await this.analyzeTransaction(tx);
                }
            }
            
            // Update last processed block
            this.lastProcessedBlock = blockNumber;
            
        } catch (error) {
            console.error(`Error processing block ${blockNumber}:`, error.message);
        }
    }

    isAAVEInteraction(address) {
        // Add AAVE contract addresses here
        const aaveAddresses = [
            process.env.AAVE_POOL_ADDRESS,
            process.env.AAVE_POOL_DATA_PROVIDER_ADDRESS
        ];
        return aaveAddresses.includes(address.toLowerCase());
    }

    async analyzeTransaction(tx) {
        try {
            // Extract user addresses from transaction
            const users = await this.extractUsersFromTx(tx);
            
            for (const user of users) {
                const liquidationData = await this.checkUserLiquidation(user);
                
                if (liquidationData && liquidationData.canBeLiquidated) {
                    const message = this.formatLiquidationAlert(user, liquidationData, tx.hash);
                    await this.sendTelegramAlert(message);
                }
            }
        } catch (error) {
            console.error('Error analyzing transaction:', error.message);
        }
    }

    async extractUsersFromTx(tx) {
        // This is a simplified implementation
        // In practice, you'd parse the transaction logs to extract user addresses
        const users = new Set();
        
        // Check if the transaction involves borrowing or supplying
        if (tx.data && tx.data.length > 10) {
            const functionSignature = tx.data.substring(0, 10);
            
            // AAVE function signatures for user interactions
            const userFunctions = [
                '0x23b872dd', // transferFrom
                '0xa9059cbb', // transfer
                '0x2e1a7d4d', // withdraw
                '0x6e553f65'  // supply
            ];
            
            if (userFunctions.includes(functionSignature)) {
                // Extract user address from transaction data
                // This is a simplified approach
                users.add(tx.from);
            }
        }
        
        return Array.from(users);
    }

    formatLiquidationAlert(user, liquidationData, txHash) {
        return `
🚨 <b>LIQUIDATION OPPORTUNITY DETECTED!</b>

👤 <b>User:</b> <code>${user}</code>
💰 <b>Total Debt:</b> ${ethers.utils.formatEther(liquidationData.totalDebtBase)} USD
🏦 <b>Total Collateral:</b> ${ethers.utils.formatEther(liquidationData.totalCollateralBase)} USD
⚡ <b>Health Factor:</b> ${ethers.utils.formatEther(liquidationData.healthFactor)}
🔗 <b>Transaction:</b> <code>${txHash}</code>

⏰ <b>Time:</b> ${new Date().toISOString()}
        `.trim();
    }

    async startMonitoring() {
        console.log('Starting AAVE liquidation monitoring...');
        
        // Listen for new blocks
        this.provider.on('block', async (blockNumber) => {
            if (blockNumber > this.lastProcessedBlock) {
                await this.processBlock(blockNumber);
            }
        });
        
        // Process historical blocks if needed
        const currentBlock = await this.provider.getBlockNumber();
        const startBlock = Math.max(this.lastProcessedBlock + 1, currentBlock - 100);
        
        for (let block = startBlock; block <= currentBlock; block++) {
            await this.processBlock(block);
        }
    }
}

// Start the monitor
const monitor = new AAVELiquidationMonitor();
monitor.startMonitoring().catch(console.error); 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {AAVELiquidationBot} from "../src/AAVELiquidationBot.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // AAVE V3 addresses (Ethereum mainnet)
        address poolAddress = vm.envAddress("AAVE_POOL_ADDRESS");
        address poolDataProviderAddress = vm.envAddress("AAVE_POOL_DATA_PROVIDER_ADDRESS");
        
        // Telegram configuration
        string memory telegramBotToken = vm.envString("TELEGRAM_BOT_TOKEN");
        string memory telegramChatId = vm.envString("TELEGRAM_CHAT_ID");
        
        console.log("Deploying AAVE Liquidation Bot...");
        console.log("Deployer:", deployer);
        console.log("AAVE Pool:", poolAddress);
        console.log("AAVE Pool Data Provider:", poolDataProviderAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        AAVELiquidationBot bot = new AAVELiquidationBot(
            poolAddress,
            poolDataProviderAddress,
            telegramBotToken,
            telegramChatId
        );
        
        vm.stopBroadcast();
        
        console.log("AAVE Liquidation Bot deployed at:", address(bot));
        console.log("Owner:", bot.owner());
        console.log("Telegram Bot Token:", bot.telegramBotToken());
        console.log("Telegram Chat ID:", bot.telegramChatId());
        console.log("Min Liquidation Amount:", bot.minLiquidationAmount());
    }
} 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";

/**
 * @title AAVE Liquidation Bot
 * @dev Monitors AAVE V3 positions for liquidation opportunities
 */
contract AAVELiquidationBot is Ownable {
    IPool public immutable pool;
    IPoolDataProvider public immutable poolDataProvider;
    
    // Telegram bot configuration
    string public telegramBotToken;
    string public telegramChatId;
    
    // Monitoring configuration
    uint256 public minLiquidationAmount = 1000e18; // Minimum amount to trigger alert (in USD)
    uint256 public lastProcessedBlock;
    
    // Events
    event LiquidationOpportunityDetected(
        address indexed user,
        address indexed asset,
        uint256 debtToCover,
        uint256 liquidatedCollateralAmount,
        uint256 timestamp
    );
    
    event TelegramAlertSent(
        address indexed user,
        string message,
        uint256 timestamp
    );
    
    event ConfigurationUpdated(
        string telegramBotToken,
        string telegramChatId,
        uint256 minLiquidationAmount
    );
    
    constructor(
        address _pool,
        address _poolDataProvider,
        string memory _telegramBotToken,
        string memory _telegramChatId
    ) Ownable(msg.sender) {
        pool = IPool(_pool);
        poolDataProvider = IPoolDataProvider(_poolDataProvider);
        telegramBotToken = _telegramBotToken;
        telegramChatId = _telegramChatId;
    }
    
    /**
     * @dev Update bot configuration
     */
    function updateConfiguration(
        string memory _telegramBotToken,
        string memory _telegramChatId,
        uint256 _minLiquidationAmount
    ) external onlyOwner {
        telegramBotToken = _telegramBotToken;
        telegramChatId = _telegramChatId;
        minLiquidationAmount = _minLiquidationAmount;
        
        emit ConfigurationUpdated(_telegramBotToken, _telegramChatId, _minLiquidationAmount);
    }
    
    /**
     * @dev Check if a user can be liquidated
     */
    function checkUserLiquidation(address user) external view returns (
        bool canBeLiquidated,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 totalCollateralBase,
        uint256 healthFactor
    ) {
        (
            uint256 userTotalCollateralBase,
            uint256 userTotalDebtBase,
            uint256 userAvailableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 userHealthFactor
        ) = pool.getUserAccountData(user);
        
        canBeLiquidated = userHealthFactor < 1e18;
        
        return (
            canBeLiquidated,
            userTotalDebtBase,
            userAvailableBorrowsBase,
            userTotalCollateralBase,
            userHealthFactor
        );
    }
    
    /**
     * @dev Get user's debt positions
     */
    function getUserDebtPositions(address user) external view returns (
        address[] memory assets,
        uint256[] memory balances,
        uint256[] memory scaledBalances
    ) {
        // Simplified implementation - in practice you'd need to get all user reserves
        assets = new address[](0);
        balances = new uint256[](0);
        scaledBalances = new uint256[](0);
    }
    
    /**
     * @dev Get user's collateral positions
     */
    function getUserCollateralPositions(address user) external view returns (
        address[] memory assets,
        uint256[] memory balances,
        uint256[] memory scaledBalances
    ) {
        // Simplified implementation - in practice you'd need to get all user reserves
        assets = new address[](0);
        balances = new uint256[](0);
        scaledBalances = new uint256[](0);
    }
    
    /**
     * @dev Calculate liquidation amount for a specific asset
     */
    function calculateLiquidationAmount(
        address user,
        address asset
    ) external view returns (uint256 debtToCover, uint256 liquidatedCollateralAmount) {
        // This is a simplified calculation
        // In practice, you'd need to implement the full AAVE liquidation logic
        (,,,,, uint256 healthFactor) = pool.getUserAccountData(user);
        bool canBeLiquidated = healthFactor < 1e18;
        
        if (!canBeLiquidated) {
            return (0, 0);
        }
        
        // Get user's debt in the specific asset
        (uint256 currentATokenBalance, uint256 currentStableDebt, uint256 currentVariableDebt, uint256 principalStableDebt, uint256 scaledVariableDebt, uint256 stableBorrowRate, uint256 liquidityRate, uint40 stableRateLastUpdated, bool usageAsCollateralEnabled) = poolDataProvider.getUserReserveData(asset, user);
        
        debtToCover = currentVariableDebt + currentStableDebt;
        
        // Simplified liquidation calculation
        // In practice, you'd need to implement the full AAVE liquidation formula
        liquidatedCollateralAmount = debtToCover * 110 / 100; // 110% of debt as collateral
        
        return (debtToCover, liquidatedCollateralAmount);
    }
    
    /**
     * @dev Process a block and check for liquidation opportunities
     */
    function processBlock(uint256 blockNumber) external {
        require(blockNumber > lastProcessedBlock, "Block already processed");
        lastProcessedBlock = blockNumber;
        
        // In a real implementation, you would:
        // 1. Get all users who have borrowed from AAVE
        // 2. Check their health factors
        // 3. Calculate liquidation amounts
        // 4. Send alerts for profitable opportunities
        
        console.log("Processing block:", blockNumber);
    }
    
    /**
     * @dev Simulate liquidation for testing purposes
     */
    function simulateLiquidation(
        address user,
        address asset,
        uint256 debtToCover
    ) external {
        (,,,,, uint256 healthFactor) = pool.getUserAccountData(user);
        bool canBeLiquidated = healthFactor < 1e18;
        
        if (canBeLiquidated && debtToCover >= minLiquidationAmount) {
            emit LiquidationOpportunityDetected(
                user,
                asset,
                debtToCover,
                debtToCover * 110 / 100, // Simplified calculation
                block.timestamp
            );
            
            // Send Telegram alert
            string memory message = string(abi.encodePacked(
                "LIQUIDATION OPPORTUNITY DETECTED!\n",
                "User: ", addressToString(user), "\n",
                "Asset: ", addressToString(asset), "\n",
                "Debt to Cover: ", uintToString(debtToCover), "\n",
                "Block: ", uintToString(block.number)
            ));
            
            emit TelegramAlertSent(user, message, block.timestamp);
        }
    }
    
    /**
     * @dev Helper function to convert address to string
     */
    function addressToString(address addr) public pure returns (string memory) {
        bytes memory buffer = new bytes(42);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(addr)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            buffer[2 + 2*i] = char(hi);
            buffer[2 + 2*i + 1] = char(lo);
        }
        return string(buffer);
    }
    
    /**
     * @dev Helper function to convert uint to string
     */
    function uintToString(uint256 value) public pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    
    /**
     * @dev Helper function to convert bytes1 to char
     */
    function char(bytes1 b) public pure returns (bytes1) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
} 
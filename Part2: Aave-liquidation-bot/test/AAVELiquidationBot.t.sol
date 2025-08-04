// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {AAVELiquidationBot} from "../src/AAVELiquidationBot.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IPoolDataProvider} from "aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract AAVELiquidationBotTest is Test {
    AAVELiquidationBot public bot;
    
    // Mock addresses for testing
    address public constant MOCK_POOL = address(0x1234567890123456789012345678901234567890);
    address public constant MOCK_POOL_DATA_PROVIDER = address(0x2345678901234567890123456789012345678901);
    address public constant MOCK_USER = address(0x3456789012345678901234567890123456789012);
    address public constant MOCK_ASSET = address(0x4567890123456789012345678901234567890123);
    
    // Test configuration
    string public constant TELEGRAM_BOT_TOKEN = "test_bot_token";
    string public constant TELEGRAM_CHAT_ID = "test_chat_id";
    
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
    
    function setUp() public {
        bot = new AAVELiquidationBot(
            MOCK_POOL,
            MOCK_POOL_DATA_PROVIDER,
            TELEGRAM_BOT_TOKEN,
            TELEGRAM_CHAT_ID
        );
    }
    
    function test_Constructor() public {
        assertEq(address(bot.pool()), MOCK_POOL);
        assertEq(address(bot.poolDataProvider()), MOCK_POOL_DATA_PROVIDER);
        assertEq(bot.telegramBotToken(), TELEGRAM_BOT_TOKEN);
        assertEq(bot.telegramChatId(), TELEGRAM_CHAT_ID);
        assertEq(bot.minLiquidationAmount(), 1000e18);
    }
    
    function test_UpdateConfiguration() public {
        string memory newToken = "new_bot_token";
        string memory newChatId = "new_chat_id";
        uint256 newMinAmount = 2000e18;
        
        vm.expectEmit(true, true, true, true);
        emit ConfigurationUpdated(newToken, newChatId, newMinAmount);
        
        bot.updateConfiguration(newToken, newChatId, newMinAmount);
        
        assertEq(bot.telegramBotToken(), newToken);
        assertEq(bot.telegramChatId(), newChatId);
        assertEq(bot.minLiquidationAmount(), newMinAmount);
    }
    
    function test_UpdateConfiguration_OnlyOwner() public {
        vm.prank(address(0x999));
        vm.expectRevert("Ownable: caller is not the owner");
        bot.updateConfiguration("", "", 0);
    }
    
    function test_ProcessBlock() public {
        uint256 blockNumber = 1000;
        
        // Mock the console.log call
        vm.mockCall(
            address(0),
            abi.encodeWithSignature("console.log(string,uint256)"),
            abi.encode()
        );
        
        bot.processBlock(blockNumber);
        assertEq(bot.lastProcessedBlock(), blockNumber);
    }
    
    function test_ProcessBlock_AlreadyProcessed() public {
        uint256 blockNumber = 1000;
        bot.processBlock(blockNumber);
        
        vm.expectRevert("Block already processed");
        bot.processBlock(blockNumber);
    }
    
    function test_SimulateLiquidation_UserCanBeLiquidated() public {
        // Mock the pool to return data indicating user can be liquidated
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
        
        vm.expectEmit(true, true, true, true);
        emit LiquidationOpportunityDetected(
            MOCK_USER,
            MOCK_ASSET,
            debtToCover,
            debtToCover * 110 / 100,
            block.timestamp
        );
        
        vm.expectEmit(true, true, true, true);
        emit TelegramAlertSent(
            MOCK_USER,
            "", // Message will be generated
            block.timestamp
        );
        
        bot.simulateLiquidation(MOCK_USER, MOCK_ASSET, debtToCover);
    }
    
    function test_SimulateLiquidation_UserCannotBeLiquidated() public {
        // Mock the pool to return data indicating user cannot be liquidated
        vm.mockCall(
            MOCK_POOL,
            abi.encodeWithSignature("getUserAccountData(address)"),
            abi.encode(
                1000e18, // totalCollateralBase
                500e18,  // totalDebtBase
                500e18,  // availableBorrowsBase
                8000,    // currentLiquidationThreshold
                7500,    // ltv
                2e18     // healthFactor (2.0, above 1.0 threshold)
            )
        );
        
        uint256 debtToCover = 1500e18;
        
        // Should not emit any events
        bot.simulateLiquidation(MOCK_USER, MOCK_ASSET, debtToCover);
    }
    
    function test_SimulateLiquidation_BelowMinimumAmount() public {
        // Mock the pool to return data indicating user can be liquidated
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
        
        uint256 debtToCover = 500e18; // Below minimum amount
        
        // Should not emit any events
        bot.simulateLiquidation(MOCK_USER, MOCK_ASSET, debtToCover);
    }
    
    function test_CheckUserLiquidation() public {
        // Mock the pool to return specific user data
        vm.mockCall(
            MOCK_POOL,
            abi.encodeWithSignature("getUserAccountData(address)"),
            abi.encode(
                1000e18, // totalCollateralBase
                2000e18, // totalDebtBase
                0,       // availableBorrowsBase
                8000,    // currentLiquidationThreshold
                7500,    // ltv
                5e17     // healthFactor
            )
        );
        
        (
            bool canBeLiquidated,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 totalCollateralBase,
            uint256 healthFactor
        ) = bot.checkUserLiquidation(MOCK_USER);
        
        assertTrue(canBeLiquidated);
        assertEq(totalDebtBase, 2000e18);
        assertEq(availableBorrowsBase, 0);
        assertEq(totalCollateralBase, 1000e18);
        assertEq(healthFactor, 5e17);
    }
    
    function test_CalculateLiquidationAmount_UserCannotBeLiquidated() public {
        // Mock the pool to return data indicating user cannot be liquidated
        vm.mockCall(
            MOCK_POOL,
            abi.encodeWithSignature("getUserAccountData(address)"),
            abi.encode(
                1000e18, // totalCollateralBase
                500e18,  // totalDebtBase
                500e18,  // availableBorrowsBase
                8000,    // currentLiquidationThreshold
                7500,    // ltv
                2e18     // healthFactor
            )
        );
        
        (uint256 debtToCover, uint256 liquidatedCollateralAmount) = bot.calculateLiquidationAmount(MOCK_USER, MOCK_ASSET);
        
        assertEq(debtToCover, 0);
        assertEq(liquidatedCollateralAmount, 0);
    }
    
    function test_CalculateLiquidationAmount_UserCanBeLiquidated() public {
        // Mock the pool to return data indicating user can be liquidated
        vm.mockCall(
            MOCK_POOL,
            abi.encodeWithSignature("getUserAccountData(address)"),
            abi.encode(
                1000e18, // totalCollateralBase
                2000e18, // totalDebtBase
                0,       // availableBorrowsBase
                8000,    // currentLiquidationThreshold
                7500,    // ltv
                5e17     // healthFactor
            )
        );
        
        // Mock the pool data provider
        vm.mockCall(
            MOCK_POOL_DATA_PROVIDER,
            abi.encodeWithSignature("getUserReserveData(address,address)"),
            abi.encode(
                0,       // scaledBalance
                0,       // currentATokenBalance
                1000e18, // scaledVariableDebt
                500e18,  // scaledStableDebt
                0,       // principalStableDebt
                0,       // stableBorrowRate
                0,       // oldStableBorrowRate
                0        // stableBorrowLastUpdateTimestamp
            )
        );
        
        (uint256 debtToCover, uint256 liquidatedCollateralAmount) = bot.calculateLiquidationAmount(MOCK_USER, MOCK_ASSET);
        
        assertEq(debtToCover, 1500e18); // 1000e18 + 500e18
        assertEq(liquidatedCollateralAmount, 1650e18); // 1500e18 * 110 / 100
    }
    
    function test_AddressToString() public {
        address testAddr = 0x1234567890123456789012345678901234567890;
        string memory result = bot.addressToString(testAddr);
        assertEq(result, "0x1234567890123456789012345678901234567890");
    }
    
    function test_UintToString() public {
        uint256 testValue = 123456789;
        string memory result = bot.uintToString(testValue);
        assertEq(result, "123456789");
    }
    
    function test_UintToString_Zero() public {
        uint256 testValue = 0;
        string memory result = bot.uintToString(testValue);
        assertEq(result, "0");
    }
    
    // Test liquidation at specific point in time
    function test_LiquidationAtSpecificTime() public {
        // Set a specific timestamp
        uint256 specificTime = 1640995200; // January 1, 2022
        vm.warp(specificTime);
        
        // Mock the pool to return data indicating user can be liquidated
        vm.mockCall(
            MOCK_POOL,
            abi.encodeWithSignature("getUserAccountData(address)"),
            abi.encode(
                1000e18, // totalCollateralBase
                2000e18, // totalDebtBase
                0,       // availableBorrowsBase
                8000,    // currentLiquidationThreshold
                7500,    // ltv
                5e17     // healthFactor
            )
        );
        
        uint256 debtToCover = 1500e18;
        
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
    
    // Test multiple liquidation scenarios
    function test_MultipleLiquidationScenarios() public {
        address[] memory users = new address[](3);
        users[0] = address(0x111);
        users[1] = address(0x222);
        users[2] = address(0x333);
        
        uint256[] memory healthFactors = new uint256[](3);
        healthFactors[0] = 5e17; // Can be liquidated
        healthFactors[1] = 2e18; // Cannot be liquidated
        healthFactors[2] = 8e17; // Can be liquidated
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.mockCall(
                MOCK_POOL,
                abi.encodeWithSignature("getUserAccountData(address)"),
                abi.encode(
                    1000e18, // totalCollateralBase
                    2000e18, // totalDebtBase
                    0,       // availableBorrowsBase
                    8000,    // currentLiquidationThreshold
                    7500,    // ltv
                    healthFactors[i]
                )
            );
            
            uint256 debtToCover = 1500e18;
            
            if (healthFactors[i] < 1e18) {
                vm.expectEmit(true, true, true, true);
                emit LiquidationOpportunityDetected(
                    users[i],
                    MOCK_ASSET,
                    debtToCover,
                    debtToCover * 110 / 100,
                    block.timestamp
                );
            }
            
            bot.simulateLiquidation(users[i], MOCK_ASSET, debtToCover);
        }
    }
} 
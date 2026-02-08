// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "../src/strategies/PeakSellingStrategy.sol";
import "./mocks/MockUniswapPool.sol";
import "./mocks/MockERC20.sol";

contract PeakSellingStrategyTest is Test {
    Vault public vault;
    PeakSellingStrategy public strategy;
    MockUniswapPoolTargeted public pool;
    MockERC20 public usdc;
    MockERC20 public weth;
    MockSwapRouter public router;

    address public owner = address(1);
    address public searcher = address(2);

    function setUp() public {
        vm.startPrank(owner);
        
        pool = new MockUniswapPoolTargeted();
        usdc = new MockERC20();
        weth = new MockERC20();
        router = new MockSwapRouter();
        vault = new Vault();
        
        // Strategy Config: Sell WETH for USDC when price RISES 1%
        int24 tickRiseThreshold = 100;
        uint32 observationWindow = 300; 
        uint256 sellAmount = 1 ether; // Sell 1 WETH
        uint256 bounty = 0.1 ether;
        
        strategy = new PeakSellingStrategy(
            address(vault),
            address(pool),
            address(router),
            address(weth), // Sell WETH
            address(usdc), // Buy USDC
            3000,
            tickRiseThreshold,
            observationWindow,
            sellAmount,
            bounty
        );
        
        vault.addStrategy(address(strategy));
        
        // Fund Vault with WETH to sell
        weth.mint(address(vault), 10 ether);
        // Fund Vault with ETH for bounties
        vm.deal(address(vault), 10 ether);
        
        // Approve Strategy to spend Vault's WETH
        vault.approveStrategy(address(weth), address(strategy), type(uint256).max);
        
        vm.stopPrank();
    }

    // --- Improved Test Cases ---

    function test_PriceRiseTrigger_ExactThreshold() public {
        // Threshold 100.
        // Past 1000.
        // Rise > 100.
        // Current 1101. Diff +101.
        pool.setPrice(1101, 1000);
        
        vm.startPrank(searcher);
        (bool canExec, ) = strategy.checkCondition("");
        assertTrue(canExec, "Should execute on exact rise > threshold");
        vault.executeStrategy(address(strategy), "");
        vm.stopPrank();
    }

    function testFuzz_PriceRise(int24 currentTick, int56 pastTick) public {
        currentTick = int24(bound(currentTick, -880000, 880000));
        pastTick = int56(bound(pastTick, -880000, 880000));
        
        pool.setPrice(currentTick, pastTick);

        bool shouldExecute = (int56(currentTick) - pastTick) > int56(100);
        
        (bool canExec, ) = strategy.checkCondition("");
        
        if (shouldExecute) {
            assertTrue(canExec, "Fuzz: Should have executed");
        } else {
            assertFalse(canExec, "Fuzz: Should not have executed");
        }
    }
    
    function test_Revert_WhenStrategyNotWhitelisted() public {
        // Deploy a new random strategy not added to vault
        PeakSellingStrategy badStrategy = new PeakSellingStrategy(
            address(vault), address(pool), address(router), 
            address(weth), address(usdc), 3000, 100, 300, 1 ether, 0.1 ether
        );
        
        vm.startPrank(searcher);
        vm.expectRevert("Strategy not active");
        vault.executeStrategy(address(badStrategy), "");
        vm.stopPrank();
    }
    
    function test_BountyPaymentFailure() public {
        // Drain the vault's ETH so bounty fails
        vm.stopPrank();
        
        vm.prank(owner);
        vault.withdrawETH(address(vault).balance); // Empty vault
        
        // ensure vault has 0 ETH
        assertEq(address(vault).balance, 0);
        
        // Trigger condition
        pool.setPrice(1200, 1000);
        
        vm.startPrank(searcher);
        vm.expectRevert(); // Generic revert to catch failure
        vault.executeStrategy(address(strategy), "");
        vm.stopPrank();
    }
    
    function test_StrategyManagement() public {
        vm.startPrank(owner);
        
        // Add new random strategy
        address newStrategy = address(0x123);
        vault.addStrategy(newStrategy);
        assertTrue(vault.activeStrategies(newStrategy));
        
        // Remove it
        vault.removeStrategy(newStrategy);
        assertFalse(vault.activeStrategies(newStrategy));
        
        vm.stopPrank();
        
        // Try to execute removed strategy
        vm.startPrank(searcher);
        vm.expectRevert("Strategy not active");
        vault.executeStrategy(newStrategy, "");
        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "../src/strategies/DipBuyingStrategy.sol";
import "./mocks/MockUniswapPool.sol";
import "./mocks/MockERC20.sol";

contract DipBuyingStrategyTest is Test {
    Vault public vault;
    DipBuyingStrategy public strategy;
    MockUniswapPoolTargeted public pool;
    MockERC20 public usdc;
    MockERC20 public weth;
    MockSwapRouter public router;

    address public owner = address(1);
    address public searcher = address(2);

    function setUp() public {
        vm.startPrank(owner);
        
        // Setup Mocks
        pool = new MockUniswapPoolTargeted();
        usdc = new MockERC20();
        weth = new MockERC20();
        router = new MockSwapRouter();
        
        // Setup Vault
        vault = new Vault();
        
        // Strategy Config
        // 1% drop threshold. 
        // 1% approx 100 ticks.
        int24 tickDropThreshold = 100;
        uint32 observationWindow = 300; 
        uint256 buyAmount = 1000e6; // 1000 USDC
        uint256 bounty = 0.1 ether;
        
        strategy = new DipBuyingStrategy(
            address(vault),
            address(pool),
            address(router),
            address(usdc),
            address(weth),
            3000,
            tickDropThreshold,
            observationWindow,
            buyAmount,
            bounty
        );
        
        // Whitelist Strategy
        vault.addStrategy(address(strategy));
        
        // Fund Vault with USDC
        usdc.mint(address(vault), 10000e6);
        // Fund Vault with ETH for bounties
        vm.deal(address(vault), 10 ether);
        
        // Approve Strategy to spend Vault's USDC
        vault.approveStrategy(address(usdc), address(strategy), type(uint256).max);
        
        vm.stopPrank();
    }

    // --- Improved Test Cases ---

    function test_PriceDropTrigger_ExactThreshold() public {
        // Threshold is 100.
        // Past = 1000.
        // Drop needs to be > 100.
        // If Current = 899. Diff = -101. Should trigger.
        pool.setPrice(899, 1000);
        
        vm.startPrank(searcher);
        (bool canExec, ) = strategy.checkCondition("");
        assertTrue(canExec, "Should execute on exact drop > threshold");
        vault.executeStrategy(address(strategy), "");
        vm.stopPrank();
    }

    function test_Revert_PriceDrop_JustMissed() public {
        // Threshold is 100.
        // Current = 900. Diff = -100. Not < -100.
        pool.setPrice(900, 1000);
        
        vm.startPrank(searcher);
        (bool canExec, ) = strategy.checkCondition("");
        assertFalse(canExec, "Should NOT execute if drop == threshold");
        
        vm.expectRevert("Condition not met");
        vault.executeStrategy(address(strategy), "");
        vm.stopPrank();
    }

    function test_Revert_OnlyVaultCanExecute() public {
        // Even if condition is met, calling strategy.execute DIRECTLY should fail
        pool.setPrice(800, 1000);
        
        vm.startPrank(searcher);
        vm.expectRevert(DipBuyingStrategy.NotVault.selector);
        strategy.execute("");
        vm.stopPrank();
    }

    // Fuzz Test: Random prices
    function testFuzz_PriceDrop(int24 currentTick, int56 pastTick) public {
        // Constrain inputs to reasonable tick ranges (Uniswap V3 ticks ~ -887272 to 887272)
        currentTick = int24(bound(currentTick, -880000, 880000));
        pastTick = int56(bound(pastTick, -880000, 880000));
        
        pool.setPrice(currentTick, pastTick);

        bool shouldExecute = (int56(currentTick) - pastTick) < -int56(100);
        
        (bool canExec, ) = strategy.checkCondition("");
        
        if (shouldExecute) {
            assertTrue(canExec, "Fuzz: Should have executed");
        } else {
            assertFalse(canExec, "Fuzz: Should not have executed");
        }
    }
    
    function test_AccessControl_AddStrategy() public {
        vm.startPrank(searcher); // Not owner
        vm.expectRevert("Only owner");
        vault.addStrategy(address(0));
        vm.stopPrank();
    }
}

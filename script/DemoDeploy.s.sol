// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Vault.sol";
import "../src/strategies/DipBuyingStrategy.sol";
import "../src/strategies/PeakSellingStrategy.sol";
import "../test/mocks/MockUniswapPool.sol";
import "../test/mocks/MockERC20.sol";

contract DemoDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Mocks
        MockUniswapPoolTargeted pool = new MockUniswapPoolTargeted();
        MockERC20 usdc = new MockERC20();
        MockERC20 weth = new MockERC20();
        MockSwapRouter router = new MockSwapRouter();
        
        console.log("Mock Pool:", address(pool));
        console.log("Mock USDC:", address(usdc));
        console.log("Mock WETH:", address(weth));
        
        // 2. Deploy Vault
        Vault vault = new Vault();
        console.log("Vault:", address(vault));

        // 3. Deploy Strategies
        // 1% Dip Buy
        DipBuyingStrategy buyStrategy = new DipBuyingStrategy(
            address(vault), address(pool), address(router), 
            address(usdc), address(weth), 3000, 100, 300, 1000e6, 0.01 ether
        );
        
        // 1% Peak Sell
        PeakSellingStrategy sellStrategy = new PeakSellingStrategy(
            address(vault), address(pool), address(router), 
            address(weth), address(usdc), 3000, 100, 300, 1 ether, 0.01 ether
        );
        
        vault.addStrategy(address(buyStrategy));
        vault.addStrategy(address(sellStrategy));
        
        console.log("Buy Strategy:", address(buyStrategy));
        console.log("Sell Strategy:", address(sellStrategy));
        
        // 4. Initial Setup
        // Mint funds to Vault
        usdc.mint(address(vault), 100000e6);
        weth.mint(address(vault), 100 ether);
        
        // Approve strategies
        vault.approveStrategy(address(usdc), address(buyStrategy), type(uint256).max);
        vault.approveStrategy(address(weth), address(sellStrategy), type(uint256).max);
        
        // Set Initial Price (Stable)
        pool.setPrice(1000, 1000);
        
        vm.stopBroadcast();
    }
}

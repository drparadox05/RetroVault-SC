// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IStrategy.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswap.sol";
import "../lib/UniswapOracleLib.sol";

contract DipBuyingStrategy is IStrategy {
    using UniswapOracleLib for address;

    address public immutable vault;
    address public immutable pool;
    address public immutable swapRouter;
    address public immutable tokenIn; // Asset we hold (e.g. USDC)
    address public immutable tokenOut; // Asset we want to buy (e.g. WETH)
    uint24 public immutable poolFee;
    
    int24 public immutable tickDropThreshold; // e.g. 100 for ~1%
    uint32 public immutable observationWindow; // e.g. 300 seconds (5 mins)
    uint256 public buyAmount; // Fixed amount to buy per dip (simplification)
    uint256 public bounty;    // Bounty to pay searcher

    error NotVault();
    error ConditionNotMet();

    constructor(
        address _vault,
        address _pool,
        address _swapRouter,
        address _tokenIn,
        address _tokenOut,
        uint24 _fee,
        int24 _tickDropThreshold,
        uint32 _observationWindow,
        uint256 _buyAmount,
        uint256 _bounty
    ) {
        vault = _vault;
        pool = _pool;
        swapRouter = _swapRouter;
        tokenIn = _tokenIn;
        tokenOut = _tokenOut;
        poolFee = _fee;
        tickDropThreshold = _tickDropThreshold;
        observationWindow = _observationWindow;
        buyAmount = _buyAmount;
        bounty = _bounty;
    }

    function checkCondition(bytes calldata /*data*/) external view returns (bool canExec, uint256 bountyAmount) {
        // Check Oracle for price drop
        // We want to see if Current Price < Past Price - Threshold
        // i.e. Has price dropped?
        bool dropped = UniswapOracleLib.hasPriceDropped(pool, observationWindow, tickDropThreshold);
        
        if (dropped) {
            return (true, bounty);
        }
        return (false, 0);
    }

    function execute(bytes calldata /*data*/) external {
        if (msg.sender != vault) revert NotVault();

        // 1. Verify Condition again to be safe
        (bool canExec, ) = this.checkCondition("");
        if (!canExec) revert ConditionNotMet(); // Enforce condition on-chain

        // 2. Pull funds from Vault
        // Vault must have approved this strategy
        IERC20(tokenIn).transferFrom(vault, address(this), buyAmount);

        // 3. Approve Router
        IERC20(tokenIn).approve(swapRouter, buyAmount);

        // 4. Swap on Uniswap
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: poolFee,
            recipient: vault, // Send bought tokens back to Vault
            deadline: block.timestamp,
            amountIn: buyAmount,
            amountOutMinimum: 0, // Slippage protection should be calculated, 0 for demo/hackathon
            sqrtPriceLimitX96: 0
        });

        ISwapRouter(swapRouter).exactInputSingle(params);
        
        // Bounty is handled by the Vault
    }
}

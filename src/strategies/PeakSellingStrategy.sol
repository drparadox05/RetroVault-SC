// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IStrategy.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswap.sol";
import "../lib/UniswapOracleLib.sol";

contract PeakSellingStrategy is IStrategy {
    using UniswapOracleLib for address;

    address public immutable vault;
    address public immutable pool;
    address public immutable swapRouter;
    address public immutable tokenToSell; // Asset we hold and want to sell (e.g. WETH)
    address public immutable tokenToBuy;  // Asset we want to get (e.g. USDC)
    uint24 public immutable poolFee;
    
    int24 public immutable tickRiseThreshold; // 100 for ~1%
    uint32 public immutable observationWindow; 
    uint256 public sellAmount; 
    uint256 public bounty;   

    error NotVault();
    error ConditionNotMet();

    constructor(
        address _vault,
        address _pool,
        address _swapRouter,
        address _tokenToSell,
        address _tokenToBuy,
        uint24 _fee,
        int24 _tickRiseThreshold,
        uint32 _observationWindow,
        uint256 _sellAmount,
        uint256 _bounty
    ) {
        vault = _vault;
        pool = _pool;
        swapRouter = _swapRouter;
        tokenToSell = _tokenToSell;
        tokenToBuy = _tokenToBuy;
        poolFee = _fee;
        tickRiseThreshold = _tickRiseThreshold;
        observationWindow = _observationWindow;
        sellAmount = _sellAmount;
        bounty = _bounty;
    }

    function checkCondition(bytes calldata /*data*/) external view returns (bool canExec, uint256 bountyAmount) {
        bool risen = UniswapOracleLib.hasPriceIncreased(pool, observationWindow, tickRiseThreshold);
        if (risen) {
            return (true, bounty);
        }
        return (false, 0);
    }

    function execute(bytes calldata /*data*/) external {
        if (msg.sender != vault) revert NotVault();

        (bool canExec, ) = this.checkCondition("");
        if (!canExec) revert ConditionNotMet(); 

        IERC20(tokenToSell).transferFrom(vault, address(this), sellAmount);
        IERC20(tokenToSell).approve(swapRouter, sellAmount);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenToSell,
            tokenOut: tokenToBuy,
            fee: poolFee,
            recipient: vault, 
            deadline: block.timestamp,
            amountIn: sellAmount,
            amountOutMinimum: 0, 
            sqrtPriceLimitX96: 0
        });

        ISwapRouter(swapRouter).exactInputSingle(params);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/interfaces/IERC20.sol";
import "../../src/interfaces/IUniswap.sol";

contract MockERC20 is IERC20 {
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;
    uint256 public override totalSupply;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }
}

contract MockSwapRouter is ISwapRouter {
    function exactInputSingle(ExactInputSingleParams calldata params) external payable override returns (uint256 amountOut) {
        // Mock swap: burn Input, mint Output
        // Router pulls from msg.sender (the Strategy) who approved it
        MockERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn); 
        // Wait, in real router, it takes from msg.sender. In our Strategy, Strategy takes from Vault, then approves Router.
        // So Strategy is msg.sender.
        // MockERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        
        // Mint output to recipient
        MockERC20(params.tokenOut).mint(params.recipient, params.amountIn); // 1:1 swap for testing
        return params.amountIn;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IVault.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IERC20.sol";

contract Vault is IVault {
    address public owner;
    mapping(address => bool) public activeStrategies;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addStrategy(address _strategy) external onlyOwner {
        activeStrategies[_strategy] = true;
        emit StrategyAdded(_strategy);
    }

    function removeStrategy(address _strategy) external onlyOwner {
        activeStrategies[_strategy] = false;
        emit StrategyRemoved(_strategy);
    }

    function executeStrategy(address _strategy, bytes calldata _data) external {
        require(activeStrategies[_strategy], "Strategy not active");

        (bool canExec, uint256 bountyAmount) = IStrategy(_strategy).checkCondition(_data);
        require(canExec, "Condition not met");

        IStrategy(_strategy).execute(_data);

        if (bountyAmount > 0) {
            (bool success, ) = payable(msg.sender).call{value: bountyAmount}("");
            require(success, "Bounty payment failed");
        }
        
        emit StrategyExecuted(_strategy, bountyAmount);
    }
    
    // Allow Vault to receive ETH for bounties
    receive() external payable {}

    // Owner can withdraw funds/bounties
    function withdrawETH(uint256 amount) external onlyOwner {
        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Transfer failed");
    }
    
    function approveStrategy(address _token, address _strategy, uint256 _amount) external onlyOwner {
        IERC20(_token).approve(_strategy, _amount);
    }
}

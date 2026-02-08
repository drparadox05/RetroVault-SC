// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVault {
    event StrategyAdded(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event StrategyExecuted(address indexed strategy, uint256 bountyPaid);

    function addStrategy(address _strategy) external;
    function removeStrategy(address _strategy) external;
    
    // Called by searchers/keepers
    function executeStrategy(address _strategy, bytes calldata _data) external;
}

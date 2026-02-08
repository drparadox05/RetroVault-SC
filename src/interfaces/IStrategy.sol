// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStrategy {
    // Returns true if the strategy condition is met. 
    // Also returns the bounty amount that should be paid to the caller.
    function checkCondition(bytes calldata _data) external view returns (bool canExec, uint256 bountyAmount);
    
    // Executes the strategy logic (e.g., swap). 
    // Should be called only by the Vault.
    function execute(bytes calldata _data) external;
}

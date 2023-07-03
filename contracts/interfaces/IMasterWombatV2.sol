// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.5;

/**
 * @dev Interface of the MasterWombatV2
 */
interface IMasterWombatV2 {
    function getAssetPid(address asset) external view returns (uint256 pid);
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external returns (uint256, uint256[] memory);
    function pendingTokens(uint256 _pid, address _user) external view returns (uint256);
    function updatePool(uint256 _pid) external;
}

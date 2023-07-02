// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.5;

interface IMainPool {
    function deposit(address token, uint256 amount, uint256 minimumLiquidity, address to, uint256 deadline, bool shouldStake) external returns (uint256 liquidity);
    function withdraw(address token, uint256 liquidity, uint256 minimumAmount, address to, uint256 deadline) external returns (uint256 amount);
    function swap(address fromToken, address toToken, uint256 fromAmount, uint256 minimumToAmount, address to, uint256 deadline) external returns (uint256 actualToAmount, uint256 haircut);
    function quotePotentialDeposit(address token, uint256 amount) external view returns (uint256 liquidity, uint256 reward);
    function quotePotentialSwap(address fromToken, address toToken, int256 fromAmount) external view returns (uint256 potentialOutcome, uint256 haircut);
    function quotePotentialWithdraw(address token, uint256 liquidity) external view returns (uint256 amount, uint256 fee);
}

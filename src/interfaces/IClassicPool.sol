// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

// Also fits Uniswap v2's pairs, whose narrower getReserves types fill the same words, and Slipstream's token0, token1.
interface IClassicPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast);
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
    function getAmountOutWithTotalFee(uint256 amountIn, address tokenIn) external view returns (uint256);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function sync() external;
}

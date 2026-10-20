// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

// Hydrex's pairs, and Aero's and Aerodrome's classic pools. Slipstream pools have the same token0 and token1.
interface IClassicPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast);
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
    function getAmountOutWithTotalFee(uint256 amountIn, address tokenIn) external view returns (uint256);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

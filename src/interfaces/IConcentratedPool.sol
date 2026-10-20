// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

// Hydrex's Algebra pools, Aero's and Aerodrome's Slipstream pools, and Uniswap v3's pools.
interface IConcentratedPool {
    function fee() external view returns (uint24);
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

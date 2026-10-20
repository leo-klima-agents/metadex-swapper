// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {IERC20} from "../../src/interfaces/IERC20.sol";

// A constant-product pool, priced like Solidly pools and Uniswap v2 pairs. taxBps is an extra fee that only
// getAmountOutWithTotalFee and swap see, as Aero's MEV tax. A real pool lacks one or both getAmountOut functions, so
// only the fork tests catch the swapper asking the wrong one.
contract MockClassicPool {
    address public immutable token0;
    address public immutable token1;
    uint256 public immutable feeBps;
    uint256 public taxBps;
    uint256 public reserve0;
    uint256 public reserve1;

    constructor(address tokenA, address tokenB, uint256 feeBps_) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        feeBps = feeBps_;
    }

    function setTax(uint256 bps) external {
        taxBps = bps;
    }

    function sync() public {
        reserve0 = IERC20(token0).balanceOf(address(this));
        reserve1 = IERC20(token1).balanceOf(address(this));
    }

    function getReserves() external view returns (uint256, uint256, uint256) {
        return (reserve0, reserve1, block.timestamp);
    }

    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256) {
        return _amountOut(amountIn, tokenIn, feeBps);
    }

    function getAmountOutWithTotalFee(uint256 amountIn, address tokenIn) external view returns (uint256) {
        return _amountOut(amountIn, tokenIn, feeBps + taxBps);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata) external {
        require(amount0Out != 0 || amount1Out != 0, "no output");
        require(to != token0 && to != token1, "bad to");
        (uint256 r0, uint256 r1) = (reserve0, reserve1);
        if (amount0Out != 0) IERC20(token0).transfer(to, amount0Out);
        if (amount1Out != 0) IERC20(token1).transfer(to, amount1Out);
        uint256 b0 = IERC20(token0).balanceOf(address(this));
        uint256 b1 = IERC20(token1).balanceOf(address(this));
        uint256 in0 = b0 > r0 - amount0Out ? b0 - (r0 - amount0Out) : 0;
        uint256 in1 = b1 > r1 - amount1Out ? b1 - (r1 - amount1Out) : 0;
        require(in0 != 0 || in1 != 0, "no input");
        uint256 fee = feeBps + taxBps;
        require((b0 * 10_000 - in0 * fee) * (b1 * 10_000 - in1 * fee) >= r0 * r1 * 1e8, "K");
        sync();
    }

    function _amountOut(uint256 amountIn, address tokenIn, uint256 fee) internal view returns (uint256) {
        (uint256 rIn, uint256 rOut) = tokenIn == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        uint256 net = amountIn * (10_000 - fee);
        return net * rOut / (rIn * 10_000 + net);
    }
}

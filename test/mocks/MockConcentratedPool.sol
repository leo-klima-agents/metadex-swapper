// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {IERC20} from "../../src/interfaces/IERC20.sol";
import {IAlgebraSwapCallback} from "../../src/interfaces/IAlgebraSwapCallback.sol";
import {IUniswapV3SwapCallback} from "../../src/interfaces/IUniswapV3SwapCallback.sol";

// A pool at a fixed price that swaps like Algebra, Slipstream and Uniswap v3 pools: it sends the output, then asks
// the caller for the input in a callback. Each knob makes it misbehave.
contract MockConcentratedPool {
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    address public immutable token0;
    address public immutable token1;
    bool public immutable algebra;
    // token1 per token0
    uint256 public immutable num;
    uint256 public immutable den;

    uint256 public fillBps = 10_000;
    int256 public extra;
    bool public wrongSide;
    uint256 public callbacks = 1;

    constructor(address tokenA, address tokenB, bool algebra_, uint256 num_, uint256 den_) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        algebra = algebra_;
        (num, den) = tokenA < tokenB ? (num_, den_) : (den_, num_);
    }

    function misbehave(uint256 fillBps_, int256 extra_, bool wrongSide_, uint256 callbacks_) external {
        fillBps = fillBps_;
        extra = extra_;
        wrongSide = wrongSide_;
        callbacks = callbacks_;
    }

    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 limit, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1)
    {
        require(amountSpecified > 0, "exact input only");
        require(limit == (zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1), "limit");
        uint256 amountIn = uint256(amountSpecified) * fillBps / 10_000;
        uint256 out = zeroForOne ? amountIn * num / den : amountIn * den / num;
        (address tokenIn, address tokenOut) = zeroForOne ? (token0, token1) : (token1, token0);
        IERC20(tokenOut).transfer(recipient, out);

        int256 owed = int256(amountIn) + extra;
        (amount0, amount1) = zeroForOne != wrongSide ? (owed, -int256(out)) : (-int256(out), owed);
        uint256 before = IERC20(tokenIn).balanceOf(address(this));
        for (uint256 i; i < callbacks; ++i) {
            if (algebra) IAlgebraSwapCallback(msg.sender).algebraSwapCallback(amount0, amount1, data);
            else IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
        }
        require(IERC20(tokenIn).balanceOf(address(this)) >= before + uint256(owed), "IIA");
    }
}

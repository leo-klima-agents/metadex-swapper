// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Test} from "forge-std/Test.sol";

import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";
import {IAlgebraFactory} from "../src/interfaces/IAlgebraFactory.sol";
import {IAlgebraSwapCallback} from "../src/interfaces/IAlgebraSwapCallback.sol";
import {IClassicPool} from "../src/interfaces/IClassicPool.sol";
import {IConcentratedPool} from "../src/interfaces/IConcentratedPool.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IPairFactory} from "../src/interfaces/IPairFactory.sol";
import {IPoolFactory} from "../src/interfaces/IPoolFactory.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";
import {IUniswapV3Factory} from "../src/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3SwapCallback} from "../src/interfaces/IUniswapV3SwapCallback.sol";
import {IUnlockCallback} from "../src/interfaces/IUnlockCallback.sol";

contract SelectorsTest is Test {
    struct Pin {
        bytes4 selector;
        string signature;
    }

    function _pins() internal pure returns (Pin[] memory p) {
        p = new Pin[](25);
        p[0] = Pin(IERC20.balanceOf.selector, "balanceOf(address)");
        p[1] = Pin(IERC20.allowance.selector, "allowance(address,address)");
        p[2] = Pin(IERC20.transfer.selector, "transfer(address,uint256)");
        p[3] = Pin(IERC20.transferFrom.selector, "transferFrom(address,address,uint256)");
        p[4] = Pin(IPoolFactory.isPool.selector, "isPool(address)");
        p[5] = Pin(IUniswapV2Factory.getPair.selector, "getPair(address,address)");
        p[6] = Pin(IUniswapV3Factory.getPool.selector, "getPool(address,address,uint24)");
        p[7] = Pin(IPairFactory.isPair.selector, "isPair(address)");
        p[8] = Pin(IAlgebraFactory.poolByPair.selector, "poolByPair(address,address)");
        p[9] = Pin(IClassicPool.token0.selector, "token0()");
        p[10] = Pin(IClassicPool.token1.selector, "token1()");
        p[11] = Pin(IClassicPool.getReserves.selector, "getReserves()");
        p[12] = Pin(IClassicPool.getAmountOutWithTotalFee.selector, "getAmountOutWithTotalFee(uint256,address)");
        p[13] = Pin(IClassicPool.getAmountOut.selector, "getAmountOut(uint256,address)");
        p[14] = Pin(IClassicPool.swap.selector, "swap(uint256,uint256,address,bytes)");
        p[15] = Pin(IClassicPool.sync.selector, "sync()");
        p[16] = Pin(IConcentratedPool.swap.selector, "swap(address,bool,int256,uint160,bytes)");
        p[17] = Pin(IPoolManager.unlock.selector, "unlock(bytes)");
        p[18] =
            Pin(IPoolManager.swap.selector, "swap((address,address,uint24,int24,address),(bool,int256,uint160),bytes)");
        p[19] = Pin(IPoolManager.sync.selector, "sync(address)");
        p[20] = Pin(IPoolManager.settle.selector, "settle()");
        p[21] = Pin(IPoolManager.take.selector, "take(address,address,uint256)");
        p[22] = Pin(IUniswapV3SwapCallback.uniswapV3SwapCallback.selector, "uniswapV3SwapCallback(int256,int256,bytes)");
        p[23] = Pin(IUnlockCallback.unlockCallback.selector, "unlockCallback(bytes)");
        p[24] = Pin(IAlgebraSwapCallback.algebraSwapCallback.selector, "algebraSwapCallback(int256,int256,bytes)");
    }

    function test_matchSignatures() public pure {
        Pin[] memory p = _pins();
        for (uint256 i; i < p.length; ++i) {
            assertEq(p[i].selector, bytes4(keccak256(bytes(p[i].signature))), p[i].signature);
        }
    }

    function test_swapAndQuoteSignatures() public pure {
        assertEq(
            ImmutableSwapper.swap.selector,
            bytes4(keccak256("swap((address,uint256,uint256,(uint8,address,address,uint24,int24)[])[],uint256,bool)"))
        );
        assertEq(
            ImmutableSwapper.quote.selector,
            bytes4(keccak256("quote((address,uint256,uint256,(uint8,address,address,uint24,int24)[])[])"))
        );
    }

    function test_upstreamMdTable() public view {
        string memory md = vm.readFile("test/upstream/UPSTREAM.md");
        Pin[] memory p = _pins();
        for (uint256 i; i < p.length; ++i) {
            string memory row =
                string.concat("| `", p[i].signature, "` | `", vm.toString(abi.encodePacked(p[i].selector)), "` |");
            assertTrue(vm.contains(md, row), string.concat("UPSTREAM.md row missing or stale: ", row));
        }
    }
}

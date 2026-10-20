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
import {IUniswapV2Pair} from "../src/interfaces/IUniswapV2Pair.sol";
import {IUniswapV3Factory} from "../src/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3SwapCallback} from "../src/interfaces/IUniswapV3SwapCallback.sol";
import {IUnlockCallback} from "../src/interfaces/IUnlockCallback.sol";

contract SelectorsTest is Test {
    struct Pin {
        bytes4 selector;
        bytes4 literal;
        string signature;
    }

    function _pins() internal pure returns (Pin[] memory p) {
        p = new Pin[](25);
        p[0] = Pin(IERC20.balanceOf.selector, 0x70a08231, "balanceOf(address)");
        p[1] = Pin(IERC20.allowance.selector, 0xdd62ed3e, "allowance(address,address)");
        p[2] = Pin(IERC20.transfer.selector, 0xa9059cbb, "transfer(address,uint256)");
        p[3] = Pin(IERC20.transferFrom.selector, 0x23b872dd, "transferFrom(address,address,uint256)");
        p[4] = Pin(IAlgebraFactory.poolByPair.selector, 0xd9a641e1, "poolByPair(address,address)");
        p[5] = Pin(IPairFactory.isPair.selector, 0xe5e31b13, "isPair(address)");
        p[6] = Pin(IPoolFactory.isPool.selector, 0x5b16ebb7, "isPool(address)");
        p[7] = Pin(IUniswapV2Factory.getPair.selector, 0xe6a43905, "getPair(address,address)");
        p[8] = Pin(IUniswapV3Factory.getPool.selector, 0x1698ee82, "getPool(address,address,uint24)");
        p[9] = Pin(IClassicPool.token0.selector, 0x0dfe1681, "token0()");
        p[10] = Pin(IClassicPool.token1.selector, 0xd21220a7, "token1()");
        p[11] = Pin(IClassicPool.getReserves.selector, 0x0902f1ac, "getReserves()");
        p[12] = Pin(IClassicPool.getAmountOut.selector, 0xf140a35a, "getAmountOut(uint256,address)");
        p[13] = Pin(
            IClassicPool.getAmountOutWithTotalFee.selector, 0x0ea099c1, "getAmountOutWithTotalFee(uint256,address)"
        );
        p[14] = Pin(IClassicPool.swap.selector, 0x022c0d9f, "swap(uint256,uint256,address,bytes)");
        p[15] = Pin(IConcentratedPool.fee.selector, 0xddca3f43, "fee()");
        p[16] = Pin(IConcentratedPool.swap.selector, 0x128acb08, "swap(address,bool,int256,uint160,bytes)");
        p[17] = Pin(IPoolManager.unlock.selector, 0x48c89491, "unlock(bytes)");
        p[18] = Pin(
            IPoolManager.swap.selector,
            0xf3cd914c,
            "swap((address,address,uint24,int24,address),(bool,int256,uint160),bytes)"
        );
        p[19] = Pin(IPoolManager.sync.selector, 0xa5841194, "sync(address)");
        p[20] = Pin(IPoolManager.settle.selector, 0x11da60b4, "settle()");
        p[21] = Pin(IPoolManager.take.selector, 0x0b0d9c09, "take(address,address,uint256)");
        p[22] = Pin(
            IAlgebraSwapCallback.algebraSwapCallback.selector, 0x2c8958f6, "algebraSwapCallback(int256,int256,bytes)"
        );
        p[23] = Pin(
            IUniswapV3SwapCallback.uniswapV3SwapCallback.selector,
            0xfa461e33,
            "uniswapV3SwapCallback(int256,int256,bytes)"
        );
        p[24] = Pin(IUnlockCallback.unlockCallback.selector, 0x91dd7346, "unlockCallback(bytes)");
    }

    function test_selectors_matchLiteralsAndSignatures() public pure {
        Pin[] memory p = _pins();
        for (uint256 i; i < p.length; ++i) {
            assertEq(p[i].selector, p[i].literal, p[i].signature);
            assertEq(p[i].selector, bytes4(keccak256(bytes(p[i].signature))), p[i].signature);
        }
    }

    function test_selectors_sharedAcrossInterfaces() public pure {
        assertEq(IUniswapV2Pair.getReserves.selector, IClassicPool.getReserves.selector);
        assertEq(IUniswapV2Pair.swap.selector, IClassicPool.swap.selector);
    }

    function test_selectors_swapperImplementsTheCallbacks() public pure {
        assertEq(ImmutableSwapper.algebraSwapCallback.selector, IAlgebraSwapCallback.algebraSwapCallback.selector);
        assertEq(ImmutableSwapper.uniswapV3SwapCallback.selector, IUniswapV3SwapCallback.uniswapV3SwapCallback.selector);
        assertEq(ImmutableSwapper.unlockCallback.selector, IUnlockCallback.unlockCallback.selector);
    }

    function test_selectors_swappersOwn() public pure {
        assertEq(ImmutableSwapper.swap.selector, bytes4(0x17e90551));
        assertEq(ImmutableSwapper.quote.selector, bytes4(0x87242907));
        assertEq(ImmutableSwapper.runRoute.selector, bytes4(0xb6603452));
        assertEq(ImmutableSwapper.exchanges.selector, bytes4(0x21a8c177));
        assertEq(
            ImmutableSwapper.swap.selector,
            bytes4(keccak256("swap((address,uint256,uint256,(uint8,address,address,uint24,int24)[])[],uint256,bool)"))
        );
        assertEq(
            ImmutableSwapper.quote.selector,
            bytes4(keccak256("quote((address,uint256,uint256,(uint8,address,address,uint24,int24)[])[])"))
        );
    }

    function test_selectors_upstreamMdTable() public view {
        string memory md = vm.readFile("test/upstream/UPSTREAM.md");
        Pin[] memory p = _pins();
        for (uint256 i; i < p.length; ++i) {
            string memory row =
                string.concat("| `", p[i].signature, "` | `", vm.toString(abi.encodePacked(p[i].literal)), "` |");
            assertTrue(vm.contains(md, row), string.concat("UPSTREAM.md row missing or stale: ", row));
        }
    }
}

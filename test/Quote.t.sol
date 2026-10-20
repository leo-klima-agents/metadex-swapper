// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Vm} from "forge-std/Vm.sol";

import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";
import {MockConcentratedPool} from "./mocks/MockConcentratedPool.sol";
import {MockToken} from "./mocks/MockToken.sol";
import {SwapperTestBase} from "./utils/SwapperTestBase.sol";

contract QuoteTest is SwapperTestBase {
    function test_matchesSwap_threeHops() public {
        address p1 = _pool(HYDREX_CLASSIC, address(tkn), address(weth), 3, 7);
        _pool(UNISWAP_V4, address(weth), ETH, 5, 11);
        _pool(UNISWAP_V4, ETH, address(usdc), 13, 2);
        ImmutableSwapper.Route[] memory routes = _routes(
            _route(
                address(tkn),
                1e21,
                _hops(
                    _hop(HYDREX_CLASSIC, p1, address(weth)),
                    _hop(UNISWAP_V4, address(0), ETH),
                    _hop(UNISWAP_V4, address(0), address(usdc))
                )
            )
        );
        ImmutableSwapper.Result[] memory quoted = _quote(routes);
        _give(address(tkn), 1e21);
        (ImmutableSwapper.Result[] memory results,,) = _swap(routes);
        assertGt(quoted[0].amountOut, 0);
        assertEq(abi.encode(quoted[0]), abi.encode(results[0]));
    }

    function test_needsNoAllowance() public {
        ImmutableSwapper.Route memory r = _direct(UNISWAP_V3, address(tkn), 2e18);
        ImmutableSwapper.Route memory all = _direct(AERODROME_SLIPSTREAM, address(tkn), type(uint256).max);
        tkn.mint(holder, 5e18);

        ImmutableSwapper.Result[] memory quoted = _quote(_routes(r, all));

        assertEq(quoted[0].amountIn, 2e18);
        assertEq(quoted[0].amountOut, 2e18);
        assertEq(quoted[1].amountIn, 5e18, "the caller's whole balance");
        assertEq(quoted[1].amountOut, 5e18);
        assertEq(tkn.allowance(holder, address(swapper)), 0);
    }

    function test_reportsAFailingRouteWithoutReverting() public {
        ImmutableSwapper.Route memory good = _direct(UNISWAP_V2, address(tkn), 1e18);
        ImmutableSwapper.Route memory bad = _direct(HYDREX_ALGEBRA, address(weth), 1e18);
        MockConcentratedPool(bad.hops[0].pool).misbehave({fillBps_: 5000, extra_: 0, wrongSide_: false, callbacks_: 1});

        ImmutableSwapper.Result[] memory quoted = _quote(_routes(good, bad));

        assertTrue(quoted[0].done);
        assertFalse(quoted[1].done);
        assertEq(quoted[1].reason, abi.encodeWithSelector(ImmutableSwapper.PartialFill.selector, bad.hops[0].pool));
        assertEq(quoted[1].amountOut, 0);
    }

    function test_checksLikeSwap() public {
        ImmutableSwapper.Route memory r = _direct(UNISWAP_V3, address(tkn), 1e18);
        r.hops[0].exchange = AERO_SLIPSTREAM;
        r.minPaid = 1e18;
        ImmutableSwapper.Route memory short = _direct(UNISWAP_V3, address(weth), 1e18);
        short.minPaid = 1e18;

        ImmutableSwapper.Result[] memory quoted = _quote(_routes(r, short));

        assertEq(
            quoted[0].reason,
            abi.encodeWithSelector(ImmutableSwapper.NotExchangePool.selector, AERO_SLIPSTREAM, r.hops[0].pool)
        );
        assertEq(quoted[1].reason, abi.encodeWithSelector(ImmutableSwapper.TooLittle.selector, 1, 0.99e18, 1e18));
    }

    function test_pricesEachRouteAgainstThePoolsAsTheyAre() public {
        address pool = _pool(AERODROME_CLASSIC, address(tkn), address(usdc), 1, 1);
        ImmutableSwapper.Route memory r =
            _route(address(tkn), 1e27, _hops(_hop(AERODROME_CLASSIC, pool, address(usdc))));
        ImmutableSwapper.Route[] memory routes = _routes(r, r);

        ImmutableSwapper.Result[] memory quoted = _quote(routes);
        _give(address(tkn), 2e27);
        (ImmutableSwapper.Result[] memory results,,) = _swap(routes);

        assertEq(quoted[0].amountOut, quoted[1].amountOut);
        assertEq(results[0].amountOut, quoted[0].amountOut);
        assertLt(results[1].amountOut, quoted[1].amountOut, "the second route sees the first one's trade");
    }

    function test_leavesNoStateBehind() public {
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](EXCHANGES);
        for (uint256 i; i < EXCHANGES; ++i) {
            MockToken t = new MockToken();
            routes[i] = _direct(ImmutableSwapper.Exchange(i), address(t), 1e18);
            t.mint(holder, 1e18);
        }

        vm.startStateDiffRecording();
        ImmutableSwapper.Result[] memory quoted = _quote(routes);
        Vm.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();

        for (uint256 i; i < EXCHANGES; ++i) {
            assertTrue(quoted[i].done);
        }
        for (uint256 i; i < accesses.length; ++i) {
            assertEq(accesses[i].value, 0);
            for (uint256 j; j < accesses[i].storageAccesses.length; ++j) {
                Vm.StorageAccess memory s = accesses[i].storageAccesses[j];
                assertTrue(!s.isWrite || s.reverted, "quote writes nothing that stays");
            }
        }
        _give(address(tkn), 1e18);
        (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(_direct(UNISWAP_V3, address(tkn), 1e18)));
        assertTrue(results[0].done, "and nothing left recorded blocks a swap");
    }
}

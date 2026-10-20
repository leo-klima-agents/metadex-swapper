// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Vm} from "forge-std/Vm.sol";

import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";
import {MockClassicPool} from "./mocks/MockClassicPool.sol";
import {MockConcentratedPool} from "./mocks/MockConcentratedPool.sol";
import {MockToken} from "./mocks/MockToken.sol";
import {SwapperTestBase} from "./utils/SwapperTestBase.sol";

contract QuoteTest is SwapperTestBase {
    ImmutableSwapper.Exchange internal constant V4 = ImmutableSwapper.Exchange.UniswapV4;

    function _assertSame(ImmutableSwapper.Result memory a, ImmutableSwapper.Result memory b) internal pure {
        assertEq(a.done, b.done);
        assertEq(a.amountIn, b.amountIn);
        assertEq(a.usdcOut, b.usdcOut);
        assertEq(a.fee, b.fee);
        assertEq(a.reason, b.reason);
    }

    function test_quote_matchesSwap_eachExchange() public {
        ImmutableSwapper.Exchange[] memory all = _all();
        for (uint256 i; i < all.length; ++i) {
            MockToken t = new MockToken(18);
            ImmutableSwapper.Route[] memory routes = _routes(_direct(all[i], address(t), 3e18));
            ImmutableSwapper.Result[] memory quoted = _quote(routes);
            _give(address(t), 3e18);
            (ImmutableSwapper.Result[] memory results,,) = _swap(routes);
            assertTrue(quoted[0].done);
            _assertSame(quoted[0], results[0]);
        }
    }

    function test_quote_matchesSwap_threeHops() public {
        address p1 = _pool(ImmutableSwapper.Exchange.HydrexClassic, address(tkn), address(weth), 3, 7);
        _pool(V4, address(weth), ETH, 5, 11);
        _pool(V4, ETH, address(usdc), 13, 2);
        ImmutableSwapper.Route[] memory routes = _routes(
            _route(
                address(tkn),
                1e21,
                _hops(
                    _hop(ImmutableSwapper.Exchange.HydrexClassic, p1, address(weth)),
                    _hop(V4, address(0), ETH),
                    _hop(V4, address(0), address(usdc))
                )
            )
        );
        ImmutableSwapper.Result[] memory quoted = _quote(routes);
        _give(address(tkn), 1e21);
        (ImmutableSwapper.Result[] memory results,,) = _swap(routes);
        assertGt(quoted[0].usdcOut, 0);
        _assertSame(quoted[0], results[0]);
    }

    function test_quote_matchesSwap_withAerosTax() public {
        ImmutableSwapper.Route[] memory routes =
            _routes(_direct(ImmutableSwapper.Exchange.AeroStable, address(tkn), 1e18));
        MockClassicPool(routes[0].hops[0].pool).setTax(1000);
        ImmutableSwapper.Result[] memory quoted = _quote(routes);
        _give(address(tkn), 1e18);
        (ImmutableSwapper.Result[] memory results,,) = _swap(routes);
        _assertSame(quoted[0], results[0]);
    }

    function test_quote_needsNoAllowance() public {
        ImmutableSwapper.Route memory r = _direct(ImmutableSwapper.Exchange.UniswapV3, address(tkn), 2e18);
        ImmutableSwapper.Route memory all = _direct(ImmutableSwapper.Exchange.AerodromeSlipstream, address(tkn), 0);
        all.amount = type(uint256).max;
        tkn.mint(holder, 5e18);

        ImmutableSwapper.Result[] memory quoted = _quote(_routes(r, all));

        assertEq(quoted[0].amountIn, 2e18);
        assertEq(quoted[0].usdcOut, 2e18);
        assertEq(quoted[1].amountIn, 5e18, "the caller's whole balance");
        assertEq(quoted[1].usdcOut, 5e18);
        assertEq(tkn.allowance(holder, address(swapper)), 0);
    }

    function test_quote_reportsAFailingRouteWithoutReverting() public {
        ImmutableSwapper.Route memory good = _direct(ImmutableSwapper.Exchange.UniswapV2, address(tkn), 1e18);
        ImmutableSwapper.Route memory bad = _direct(ImmutableSwapper.Exchange.HydrexAlgebra, address(weth), 1e18);
        MockConcentratedPool(bad.hops[0].pool).misbehave(5000, 0, false, 1);

        ImmutableSwapper.Result[] memory quoted = _quote(_routes(good, bad));

        assertTrue(quoted[0].done);
        assertFalse(quoted[1].done);
        assertEq(quoted[1].reason, abi.encodeWithSelector(ImmutableSwapper.PartialFill.selector, bad.hops[0].pool));
        assertEq(quoted[1].usdcOut, 0);
    }

    function test_quote_checksLikeSwap() public {
        ImmutableSwapper.Route memory r = _direct(ImmutableSwapper.Exchange.UniswapV3, address(tkn), 1e18);
        r.hops[0].exchange = ImmutableSwapper.Exchange.AeroSlipstream;
        r.minPaid = 1e18;
        ImmutableSwapper.Route memory short = _direct(ImmutableSwapper.Exchange.UniswapV3, address(weth), 1e18);
        short.minPaid = 1e18;

        ImmutableSwapper.Result[] memory quoted = _quote(_routes(r, short));

        assertEq(
            quoted[0].reason,
            abi.encodeWithSelector(
                ImmutableSwapper.NotExchangePool.selector, ImmutableSwapper.Exchange.AeroSlipstream, r.hops[0].pool
            )
        );
        assertEq(quoted[1].reason, abi.encodeWithSelector(ImmutableSwapper.TooLittle.selector, 1, 0.99e18, 1e18));

        uint256 tooMany = swapper.MAX_ROUTES() + 1;
        vm.expectRevert(ImmutableSwapper.BadRouteCount.selector);
        swapper.quote(new ImmutableSwapper.Route[](0));
        vm.expectRevert(ImmutableSwapper.BadRouteCount.selector);
        swapper.quote(new ImmutableSwapper.Route[](tooMany));
    }

    function test_quote_pricesEachRouteAgainstThePoolsAsTheyAre() public {
        address pool = _pool(ImmutableSwapper.Exchange.AerodromeClassic, address(tkn), address(usdc), 1, 1);
        ImmutableSwapper.Route memory r =
            _route(address(tkn), 1e27, _hops(_hop(ImmutableSwapper.Exchange.AerodromeClassic, pool, address(usdc))));
        ImmutableSwapper.Route[] memory routes = _routes(r, r);

        ImmutableSwapper.Result[] memory quoted = _quote(routes);
        _give(address(tkn), 2e27);
        (ImmutableSwapper.Result[] memory results,,) = _swap(routes);

        assertEq(quoted[0].usdcOut, quoted[1].usdcOut);
        assertEq(results[0].usdcOut, quoted[0].usdcOut);
        assertLt(results[1].usdcOut, quoted[1].usdcOut, "the second route sees the first one's trade");
    }

    function test_quote_leavesNoStateBehind() public {
        ImmutableSwapper.Exchange[] memory all = _all();
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](all.length);
        for (uint256 i; i < all.length; ++i) {
            MockToken t = new MockToken(18);
            routes[i] = _direct(all[i], address(t), 1e18);
            t.mint(holder, 1e18);
        }

        vm.startStateDiffRecording();
        ImmutableSwapper.Result[] memory quoted = _quote(routes);
        Vm.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();

        for (uint256 i; i < all.length; ++i) {
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
        (ImmutableSwapper.Result[] memory results,,) =
            _swap(_routes(_direct(ImmutableSwapper.Exchange.UniswapV3, address(tkn), 1e18)));
        assertTrue(results[0].done, "and nothing left recorded blocks a swap");
    }
}

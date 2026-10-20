// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {MockClassicPool} from "./mocks/MockClassicPool.sol";
import {MockConcentratedPool} from "./mocks/MockConcentratedPool.sol";
import {MockToken} from "./mocks/MockToken.sol";
import {SwapperTestBase} from "./utils/SwapperTestBase.sol";

contract SwapTest is SwapperTestBase {
    ImmutableSwapper.Exchange internal constant ALGEBRA = ImmutableSwapper.Exchange.HydrexAlgebra;
    ImmutableSwapper.Exchange internal constant HYDREX_CLASSIC = ImmutableSwapper.Exchange.HydrexClassic;
    ImmutableSwapper.Exchange internal constant AERO_VOLATILE = ImmutableSwapper.Exchange.AeroVolatile;
    ImmutableSwapper.Exchange internal constant AERODROME_CLASSIC = ImmutableSwapper.Exchange.AerodromeClassic;
    ImmutableSwapper.Exchange internal constant SLIPSTREAM = ImmutableSwapper.Exchange.AerodromeSlipstream;
    ImmutableSwapper.Exchange internal constant V2 = ImmutableSwapper.Exchange.UniswapV2;
    ImmutableSwapper.Exchange internal constant V3 = ImmutableSwapper.Exchange.UniswapV3;
    ImmutableSwapper.Exchange internal constant V4 = ImmutableSwapper.Exchange.UniswapV4;

    // What a hop through a new pool of e, at one for one, pays for amount.
    function _expected(ImmutableSwapper.Exchange e, address pool, address token, uint256 amount)
        internal
        view
        returns (uint256)
    {
        if (e == V4 || _isConcentrated(e)) return amount;
        uint256 out = MockClassicPool(pool).getAmountOut(amount, token);
        return e == HYDREX_CLASSIC && out != 0 ? out - 1 : out;
    }

    function _assertEmpty(address token) internal view {
        assertEq(IERC20(token).balanceOf(address(swapper)), 0, "swapper keeps nothing");
        assertEq(usdc.balanceOf(address(swapper)), 0, "swapper keeps no USDC");
    }

    function test_oneHop_eachExchange() public {
        ImmutableSwapper.Exchange[] memory all = _all();
        for (uint256 i; i < all.length; ++i) {
            MockToken t = new MockToken(18);
            ImmutableSwapper.Route memory r = _direct(all[i], address(t), 1e18);
            uint256 expected = _expected(all[i], r.hops[0].pool, address(t), 1e18);
            _give(address(t), 1e18);
            uint256 holderBefore = usdc.balanceOf(holder);
            uint256 treasuryBefore = usdc.balanceOf(treasury);

            (ImmutableSwapper.Result[] memory results, uint256 paid, uint256 fee) = _swap(_routes(r));

            assertTrue(results[0].done);
            assertEq(results[0].amountIn, 1e18);
            assertEq(results[0].amountOut, expected);
            assertEq(results[0].fee, expected / 100);
            assertEq(fee, expected / 100);
            assertEq(paid, expected - expected / 100);
            assertEq(usdc.balanceOf(holder) - holderBefore, paid);
            assertEq(usdc.balanceOf(treasury) - treasuryBefore, fee);
            assertEq(t.balanceOf(holder), 0);
            _assertEmpty(address(t));
        }
    }

    function test_twoHops_everyPairOfExchanges() public {
        ImmutableSwapper.Exchange[] memory all = _all();
        address[EXCHANGES] memory first;
        address[EXCHANGES] memory second;
        for (uint256 i; i < all.length; ++i) {
            first[i] = _pool(all[i], address(tkn), address(weth));
            second[i] = _pool(all[i], address(weth), address(usdc));
        }
        for (uint256 i; i < all.length; ++i) {
            for (uint256 j; j < all.length; ++j) {
                ImmutableSwapper.Route memory r = _route(
                    address(tkn),
                    1e18,
                    _hops(_hop(all[i], first[i], address(weth)), _hop(all[j], second[j], address(usdc)))
                );
                ImmutableSwapper.Result[] memory quoted = _quote(_routes(r));
                _give(address(tkn), 1e18);
                (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(r));
                assertTrue(results[0].done);
                assertEq(results[0].amountOut, quoted[0].amountOut);
                assertGt(results[0].amountOut, 0.99e18);
                _assertEmpty(address(tkn));
                assertEq(weth.balanceOf(address(swapper)), 0);
            }
        }
    }

    function test_anotherOutputToken() public {
        ImmutableSwapper wethSwapper = new ImmutableSwapper(address(weth), _exchanges());
        address pool = _pool(V3, address(usdc), address(weth), 2, 1);
        address other = _pool(V3, address(tkn), address(weth));
        ImmutableSwapper.Route[] memory routes =
            _routes(_route(address(usdc), 1e6, _hops(_hop(V3, pool, address(weth)))));
        usdc.mint(holder, 1e6);
        vm.startPrank(holder);
        usdc.approve(address(wethSwapper), 1e6);
        (ImmutableSwapper.Result[] memory results, uint256 paid, uint256 fee) =
            wethSwapper.swap(routes, block.timestamp, false);

        assertEq(results[0].amountOut, 2e6);
        assertEq(fee, 2e4, "the fee is paid in the output token");
        assertEq(paid, 2e6 - 2e4);
        assertEq(weth.balanceOf(holder), paid);
        assertEq(weth.balanceOf(treasury), fee);
        assertEq(usdc.balanceOf(holder), 0);

        // Its routes must end in WETH, and none may start with it.
        routes =
            _routes(_route(address(tkn), 1e18, _hops(_hop(V3, other, address(weth)), _hop(V3, pool, address(usdc)))));
        vm.expectRevert(abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0));
        wethSwapper.swap(routes, block.timestamp, false);
        routes = _routes(_route(address(weth), 1e18, _hops(_hop(V3, pool, address(usdc)))));
        vm.expectRevert(abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0));
        wethSwapper.swap(routes, block.timestamp, false);
        vm.stopPrank();
    }

    function test_threeHops_mixed() public {
        address p1 = _pool(ALGEBRA, address(tkn), address(weth), 2, 1);
        address p2 = _pool(AERODROME_CLASSIC, address(weth), address(cbbtc), 1, 3);
        address p3 = _pool(ImmutableSwapper.Exchange.AeroStable, address(cbbtc), address(usdc), 5, 1);
        ImmutableSwapper.Route memory r = _route(
            address(tkn),
            1e18,
            _hops(
                _hop(ALGEBRA, p1, address(weth)),
                _hop(AERODROME_CLASSIC, p2, address(cbbtc)),
                _hop(ImmutableSwapper.Exchange.AeroStable, p3, address(usdc))
            )
        );
        uint256 mid = MockClassicPool(p2).getAmountOut(2e18, address(weth));
        uint256 expected = MockClassicPool(p3).getAmountOutWithTotalFee(mid, address(cbbtc));
        _give(address(tkn), 1e18);

        (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(r));

        assertEq(results[0].amountOut, expected);
        _assertEmpty(address(tkn));
        assertEq(weth.balanceOf(address(swapper)), 0);
        assertEq(cbbtc.balanceOf(address(swapper)), 0);
    }

    function test_aero_pricesWithTheTotalFee() public {
        ImmutableSwapper.Route memory r = _direct(AERO_VOLATILE, address(tkn), 1e18);
        MockClassicPool pool = MockClassicPool(r.hops[0].pool);
        pool.setTax(500);
        assertLt(pool.getAmountOutWithTotalFee(1e18, address(tkn)), pool.getAmountOut(1e18, address(tkn)));
        uint256 expected = pool.getAmountOutWithTotalFee(1e18, address(tkn));
        _give(address(tkn), 1e18);

        (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(r));

        assertEq(results[0].amountOut, expected);
    }

    function test_v4_oneHop() public {
        _give(address(tkn), 1e18);
        (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(_direct(V4, address(tkn), 1e18)));
        assertEq(results[0].amountOut, 1e18);
        _assertEmpty(address(tkn));
    }

    function test_v4_twoHopsInOneUnlock() public {
        _pool(V4, address(tkn), address(weth), 3, 1);
        _pool(V4, address(weth), address(usdc), 1, 2);
        ImmutableSwapper.Route memory r =
            _route(address(tkn), 1e18, _hops(_hop(V4, address(0), address(weth)), _hop(V4, address(0), address(usdc))));
        _give(address(tkn), 1e18);

        vm.expectCall(address(manager), abi.encodeWithSelector(IPoolManager.unlock.selector), 1);
        vm.expectCall(address(manager), abi.encodeWithSelector(IPoolManager.take.selector), 1);
        (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(r));

        assertEq(results[0].amountOut, 1.5e18);
        assertEq(manager.swappedKeys().length, 2);
        assertEq(manager.deltas(address(weth)), 0);
        _assertEmpty(address(tkn));
        assertEq(weth.balanceOf(address(swapper)), 0);
    }

    function test_v4_nativeEthBetweenTwoHops() public {
        _pool(V4, address(tkn), ETH, 2, 1);
        _pool(V4, ETH, address(usdc), 3, 1);
        ImmutableSwapper.Route memory r =
            _route(address(tkn), 1e18, _hops(_hop(V4, address(0), ETH), _hop(V4, address(0), address(usdc))));
        _give(address(tkn), 1e18);

        (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(r));

        assertEq(results[0].amountOut, 6e18);
        assertEq(address(swapper).balance, 0);
        IPoolManager.PoolKey[] memory keys = manager.swappedKeys();
        assertEq(keys[0].currency0, ETH);
        assertEq(keys[0].currency1, address(tkn));
        assertEq(keys[1].currency0, ETH);
        assertEq(keys[1].currency1, address(usdc));
    }

    function test_v4_nativeEthElsewhereReverts() public {
        address pool = _pool(V3, address(tkn), address(usdc));
        _pool(V4, ETH, address(usdc));

        ImmutableSwapper.Route memory r =
            _route(address(tkn), 1e18, _hops(_hop(V3, pool, ETH), _hop(V4, address(0), address(usdc))));
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NativeOutsideV4.selector, 0, 0));

        r = _route(address(tkn), 1e18, _hops(_hop(V4, address(0), ETH), _hop(V3, pool, address(usdc))));
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NativeOutsideV4.selector, 0, 0));

        r = _route(ETH, 1e18, _hops(_hop(V4, address(0), address(usdc))));
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0));

        r = _route(address(tkn), 1e18, _hops(_hop(V4, address(0), ETH)));
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0));
    }

    function test_v4_runBackToItsFirstToken() public {
        _pool(V4, address(tkn), address(weth));
        address pool = _pool(V3, address(tkn), address(usdc));
        ImmutableSwapper.Route memory r = _route(
            address(tkn),
            1e18,
            _hops(
                _hop(V4, address(0), address(weth)), _hop(V4, address(0), address(tkn)), _hop(V3, pool, address(usdc))
            )
        );
        bytes memory reason = abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 1);
        assertEq(_quote(_routes(r))[0].reason, reason);
        _expectRouteRevert(r, reason);
    }

    function test_v4_hopWithAPoolReverts() public {
        _pool(V4, address(tkn), address(usdc));
        ImmutableSwapper.Route memory r = _route(address(tkn), 1e18, _hops(_hop(V4, address(1), address(usdc))));
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NotExchangePool.selector, V4, address(1)));
    }

    function test_v4_keysNeverHaveHooks() public {
        _pool(V4, address(tkn), address(weth));
        _pool(V4, address(weth), address(usdc));
        (address c0, address c1) =
            address(cbbtc) < address(usdc) ? (address(cbbtc), address(usdc)) : (address(usdc), address(cbbtc));
        IPoolManager.PoolKey memory hooked = _key(c0, c1);
        hooked.hooks = makeAddr("hooks");
        manager.initialize(hooked, 1, 1);

        _give(address(tkn), 1e18);
        _swap(
            _routes(
                _route(
                    address(tkn), 1e18, _hops(_hop(V4, address(0), address(weth)), _hop(V4, address(0), address(usdc)))
                )
            )
        );
        IPoolManager.PoolKey[] memory keys = manager.swappedKeys();
        for (uint256 i; i < keys.length; ++i) {
            assertEq(keys[i].hooks, address(0));
            assertEq(keys[i].fee, V4_FEE);
            assertEq(keys[i].tickSpacing, V4_TICK_SPACING);
        }

        // A pool that exists only with hooks is out of reach.
        _expectRouteRevert(
            _route(address(cbbtc), 1e8, _hops(_hop(V4, address(0), address(usdc)))), bytes("PoolNotInitialized")
        );
    }

    function test_poolCheck_refusesAnotherExchangesPool() public {
        ImmutableSwapper.Exchange[] memory all = _all();
        for (uint256 i; i < all.length - 1; ++i) {
            ImmutableSwapper.Exchange other = all[(i + 1) % (all.length - 1)];
            address pool = _pool(other, address(tkn), address(usdc));
            ImmutableSwapper.Route memory r = _route(address(tkn), 1e18, _hops(_hop(all[i], pool, address(usdc))));
            _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NotExchangePool.selector, all[i], pool));
        }
    }

    function test_poolCheck_refusesAPoolForOtherTokens() public {
        ImmutableSwapper.Exchange[] memory all = _all();
        for (uint256 i; i < all.length - 1; ++i) {
            address pool = _pool(all[i], address(weth), address(usdc));
            ImmutableSwapper.Route memory r = _route(address(tkn), 1e18, _hops(_hop(all[i], pool, address(usdc))));
            _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NotExchangePool.selector, all[i], pool));
        }
    }

    function test_poolCheck_refusesAddressesNoFactoryMade() public {
        ImmutableSwapper.Exchange[] memory all = _all();
        address[3] memory bad = [makeAddr("nobody"), address(usdc), address(0)];
        for (uint256 i; i < all.length - 1; ++i) {
            _pool(all[i], address(tkn), address(usdc));
            for (uint256 j; j < bad.length; ++j) {
                ImmutableSwapper.Route memory r = _route(address(tkn), 1e18, _hops(_hop(all[i], bad[j], address(usdc))));
                _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NotExchangePool.selector, all[i], bad[j]));
            }
        }
    }

    function test_poolCheck_uniswapV3AsksTheFactoryAtThePoolsFee() public {
        MockConcentratedPool pool = new MockConcentratedPool(address(tkn), address(usdc), 3000, false, 1, 1);
        factories[uint256(V3)].list(address(pool), address(tkn), address(usdc), 500);
        ImmutableSwapper.Route memory r = _route(address(tkn), 1e18, _hops(_hop(V3, address(pool), address(usdc))));
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NotExchangePool.selector, V3, address(pool)));
    }

    function test_severalRoutes_sameTokenTwice() public {
        ImmutableSwapper.Route memory a = _direct(V3, address(tkn), 1e18);
        ImmutableSwapper.Route memory b = _direct(SLIPSTREAM, address(tkn), 2e18);
        _give(address(tkn), 3e18);

        (ImmutableSwapper.Result[] memory results, uint256 paid, uint256 fee) = _swap(_routes(a, b));

        assertEq(results[0].amountOut, 1e18);
        assertEq(results[1].amountOut, 2e18);
        assertEq(fee, 3e16);
        assertEq(paid, 3e18 - 3e16);
        assertEq(usdc.balanceOf(holder), paid);
        assertEq(tkn.balanceOf(holder), 0);
        _assertEmpty(address(tkn));
    }

    function test_anyNumberOfRoutes() public {
        uint256 n = 40;
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](n);
        for (uint256 i; i < n; ++i) {
            MockToken t = new MockToken(18);
            routes[i] = _direct(_all()[i % EXCHANGES], address(t), 1e18);
            _give(address(t), 1e18);
        }
        (ImmutableSwapper.Result[] memory results,,) = _swap(routes);
        for (uint256 i; i < n; ++i) {
            assertTrue(results[i].done);
        }

        vm.prank(holder);
        vm.expectRevert(ImmutableSwapper.NoRoutes.selector);
        swapper.swap(new ImmutableSwapper.Route[](0), block.timestamp, true);
    }

    function test_hopCount() public {
        address pool = _pool(V3, address(tkn), address(usdc));
        ImmutableSwapper.Hop memory h = _hop(V3, pool, address(usdc));
        _expectRouteRevert(
            _route(address(tkn), 1e18, new ImmutableSwapper.Hop[](0)),
            abi.encodeWithSelector(ImmutableSwapper.BadHopCount.selector, 0)
        );
        ImmutableSwapper.Hop[] memory four = new ImmutableSwapper.Hop[](swapper.MAX_HOPS() + 1);
        for (uint256 i; i < four.length; ++i) {
            four[i] = h;
        }
        _expectRouteRevert(
            _route(address(tkn), 1e18, four), abi.encodeWithSelector(ImmutableSwapper.BadHopCount.selector, 0)
        );
    }

    function test_skipFailed_skipsTheRouteAndPaysTheOthers() public {
        MockToken bad = new MockToken(18);
        ImmutableSwapper.Route memory a = _direct(V3, address(tkn), 1e18);
        ImmutableSwapper.Route memory b = _direct(V2, address(bad), 1e18);
        b.minPaid = 1e18;
        ImmutableSwapper.Route memory c = _direct(ALGEBRA, address(weth), 2e18);
        _give(address(tkn), 1e18);
        _give(address(bad), 1e18);
        _give(address(weth), 2e18);
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](3);
        (routes[0], routes[1], routes[2]) = (a, b, c);
        uint256 out = MockClassicPool(b.hops[0].pool).getAmountOut(1e18, address(bad));
        bytes memory reason =
            abi.encodeWithSelector(ImmutableSwapper.TooLittle.selector, 1, out - out / 100, uint256(1e18));

        address[] memory tokens = new address[](2);
        (tokens[0], tokens[1]) = (address(tkn), address(weth));
        uint256[] memory amounts = new uint256[](2);
        (amounts[0], amounts[1]) = (1e18, 2e18);
        vm.expectEmit(address(swapper));
        emit ImmutableSwapper.RouteFailed(holder, 1, address(bad), reason);
        vm.expectEmit(address(swapper));
        emit ImmutableSwapper.Swapped(holder, tokens, amounts, amounts, 3e18 - 3e16, 3e16);
        vm.prank(holder);
        (ImmutableSwapper.Result[] memory results, uint256 paid,) = swapper.swap(routes, block.timestamp, true);

        assertTrue(results[0].done);
        assertFalse(results[1].done);
        assertTrue(results[2].done);
        assertEq(results[1].reason, reason);
        assertEq(results[1].amountOut, 0);
        assertEq(bad.balanceOf(holder), 1e18, "the failed route's token stays with the caller");
        assertEq(usdc.balanceOf(holder), paid);
        assertEq(paid, 3e18 - 3e16);
        _assertEmpty(address(bad));
    }

    function test_noSkip_revertsWithTheRoutesReason() public {
        ImmutableSwapper.Route memory a = _direct(V3, address(tkn), 1e18);
        ImmutableSwapper.Route memory b = _direct(V3, address(weth), 1e18);
        b.minPaid = 1e18;
        _give(address(tkn), 1e18);
        _give(address(weth), 1e18);
        vm.prank(holder);
        vm.expectRevert(abi.encodeWithSelector(ImmutableSwapper.TooLittle.selector, 1, 0.99e18, 1e18));
        swapper.swap(_routes(a, b), block.timestamp, false);
    }

    function test_fee_onePercentOfEachRouteRoundedDown() public {
        ImmutableSwapper.Route memory a = _direct(V3, address(tkn), 199);
        ImmutableSwapper.Route memory b = _direct(V3, address(weth), 12_345);
        _give(address(tkn), 199);
        _give(address(weth), 12_345);

        (ImmutableSwapper.Result[] memory results, uint256 paid, uint256 fee) = _swap(_routes(a, b));

        assertEq(results[0].fee, 1);
        assertEq(results[1].fee, 123);
        assertEq(fee, 124);
        assertEq(paid + fee, 199 + 12_345);
        assertEq(usdc.balanceOf(treasury), 124);
        assertEq(usdc.balanceOf(holder), paid);
    }

    function test_fee_noTransferToTheTreasuryWhenZero() public {
        _give(address(tkn), 99);
        vm.expectCall(address(usdc), abi.encodeWithSelector(IERC20.transfer.selector, treasury), 0);
        (, uint256 paid, uint256 fee) = _swap(_routes(_direct(V3, address(tkn), 99)));
        assertEq(fee, 0);
        assertEq(paid, 99);
    }

    function test_minPaid_exactlyMetAndOneUnitShort() public {
        ImmutableSwapper.Route memory r = _direct(V3, address(tkn), 1e18);
        r.minPaid = 0.99e18;
        _give(address(tkn), 1e18);
        (, uint256 paid,) = _swap(_routes(r));
        assertEq(paid, 0.99e18);

        r.minPaid = 0.99e18 + 1;
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.TooLittle.selector, 0, 0.99e18, 0.99e18 + 1));
    }

    function test_deadline_metAndPassed() public {
        ImmutableSwapper.Route[] memory routes = _routes(_direct(V3, address(tkn), 1e18));
        _give(address(tkn), 1e18);
        vm.prank(holder);
        vm.expectRevert(ImmutableSwapper.Expired.selector);
        swapper.swap(routes, block.timestamp - 1, false);
        vm.prank(holder);
        swapper.swap(routes, block.timestamp, false);
    }

    function test_maxAmount_takesTheSmallerOfBalanceAndAllowance() public {
        ImmutableSwapper.Route memory r = _direct(V3, address(tkn), type(uint256).max);
        tkn.mint(holder, 5e18);
        vm.prank(holder);
        tkn.approve(address(swapper), 3e18);
        (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(r));
        assertEq(results[0].amountIn, 3e18);
        assertEq(tkn.balanceOf(holder), 2e18);

        vm.prank(holder);
        tkn.approve(address(swapper), 3e18);
        (results,,) = _swap(_routes(r));
        assertEq(results[0].amountIn, 2e18);
        assertEq(tkn.balanceOf(holder), 0);
    }

    function test_revert_usdcIn() public {
        address pool = _pool(V3, address(usdc), address(weth));
        _expectRouteRevert(
            _route(address(usdc), 1e6, _hops(_hop(V3, pool, address(usdc)))),
            abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0)
        );
    }

    function test_revert_usdcMidRoute() public {
        address p1 = _pool(V3, address(tkn), address(usdc));
        address p2 = _pool(V3, address(usdc), address(weth));
        ImmutableSwapper.Route memory r =
            _route(address(tkn), 1e18, _hops(_hop(V3, p1, address(usdc)), _hop(V3, p2, address(weth))));
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0));
    }

    function test_revert_lastTokenNotUsdc() public {
        address pool = _pool(V3, address(tkn), address(weth));
        _expectRouteRevert(
            _route(address(tkn), 1e18, _hops(_hop(V3, pool, address(weth)))),
            abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0)
        );
    }

    function test_revert_zeroToken() public {
        _expectRouteRevert(
            _route(address(0), 1e18, _hops(_hop(V4, address(0), address(usdc)))),
            abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0)
        );
    }

    function test_revert_partialFill() public {
        ImmutableSwapper.Route memory r = _direct(SLIPSTREAM, address(tkn), 1e18);
        MockConcentratedPool(r.hops[0].pool).misbehave(9000, 0, false, 1);
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.PartialFill.selector, r.hops[0].pool));

        r = _direct(V4, address(weth), 1e18);
        manager.setFill(9000);
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.PartialFill.selector, address(manager)));
    }

    function test_revert_noOutput() public {
        _expectRouteRevert(
            _direct(V2, address(tkn), 1), abi.encodeWithSelector(ImmutableSwapper.NoOutput.selector, 0, 0)
        );
        address pool = _pool(V3, address(weth), address(usdc), 1, 1e18);
        _expectRouteRevert(
            _route(address(weth), 1, _hops(_hop(V3, pool, address(usdc)))),
            abi.encodeWithSelector(ImmutableSwapper.NoOutput.selector, 0, 0)
        );
    }

    function test_callbacks_onlyTheRecordedCaller() public {
        vm.startPrank(stranger);
        vm.expectRevert(abi.encodeWithSelector(ImmutableSwapper.NotExpectedCaller.selector, stranger));
        swapper.algebraSwapCallback(1, -1, "");
        vm.expectRevert(abi.encodeWithSelector(ImmutableSwapper.NotExpectedCaller.selector, stranger));
        swapper.uniswapV3SwapCallback(1, -1, "");
        vm.expectRevert(abi.encodeWithSelector(ImmutableSwapper.NotExpectedCaller.selector, stranger));
        swapper.unlockCallback("");
        vm.stopPrank();

        ImmutableSwapper.Route memory r = _direct(ALGEBRA, address(tkn), 1e18);
        _give(address(tkn), 1e18);
        _swap(_routes(r));
        address pool = r.hops[0].pool;
        vm.prank(pool);
        vm.expectRevert(abi.encodeWithSelector(ImmutableSwapper.NotExpectedCaller.selector, pool));
        swapper.algebraSwapCallback(1, -1, "");
        vm.prank(address(manager));
        vm.expectRevert(abi.encodeWithSelector(ImmutableSwapper.NotExpectedCaller.selector, address(manager)));
        swapper.unlockCallback("");
    }

    function test_callbacks_onlyOnce() public {
        ImmutableSwapper.Route memory r = _direct(V3, address(tkn), 1e18);
        MockConcentratedPool(r.hops[0].pool).misbehave(10_000, 0, false, 2);
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NotExpectedCaller.selector, r.hops[0].pool));
    }

    function test_callbacks_onlyTheHopsTokenAndAmount() public {
        ImmutableSwapper.Route memory r = _direct(ALGEBRA, address(tkn), 1e18);
        MockConcentratedPool pool = MockConcentratedPool(r.hops[0].pool);
        bytes memory partialFill = abi.encodeWithSelector(ImmutableSwapper.PartialFill.selector, address(pool));
        pool.misbehave(10_000, 0, true, 1);
        _expectRouteRevert(r, partialFill);
        pool.misbehave(10_000, 1, false, 1);
        _expectRouteRevert(r, partialFill);
        pool.misbehave(10_000, -1, false, 1);
        _expectRouteRevert(r, partialFill);
    }

    function test_runRoute_onlyTheSwapperItself() public {
        ImmutableSwapper.Route memory r = _direct(V3, address(tkn), 1e18);
        vm.prank(stranger);
        vm.expectRevert(ImmutableSwapper.OnlySelf.selector);
        swapper.runRoute(stranger, 0, r);
        vm.prank(address(swapper));
        vm.expectRevert(ImmutableSwapper.OnlySelf.selector);
        swapper.runRoute(holder, 0, r);
    }

    function test_reentrancy_throughATokenHook() public {
        ImmutableSwapper.Exchange[4] memory es = [V2, V3, ALGEBRA, V4];
        for (uint256 e; e < es.length; ++e) {
            ImmutableSwapper.Route[] memory routes = _routes(_direct(es[e], address(tkn), 1e18));
            bytes[6] memory calls = [
                abi.encodeCall(ImmutableSwapper.swap, (routes, block.timestamp, false)),
                abi.encodeCall(ImmutableSwapper.quote, (routes)),
                abi.encodeCall(ImmutableSwapper.runRoute, (holder, 0, routes[0])),
                abi.encodeCall(ImmutableSwapper.uniswapV3SwapCallback, (1, -1, "")),
                abi.encodeCall(ImmutableSwapper.algebraSwapCallback, (1, -1, "")),
                abi.encodeCall(ImmutableSwapper.unlockCallback, (""))
            ];
            bytes memory notExpected =
                abi.encodeWithSelector(ImmutableSwapper.NotExpectedCaller.selector, address(usdc));
            bytes[6] memory reasons = [
                abi.encodeWithSelector(ImmutableSwapper.Reentrancy.selector),
                abi.encodeWithSelector(ImmutableSwapper.Reentrancy.selector),
                abi.encodeWithSelector(ImmutableSwapper.OnlySelf.selector),
                notExpected,
                notExpected,
                notExpected
            ];
            for (uint256 i; i < calls.length; ++i) {
                // The pool's transfer of USDC to the swapper calls back into it.
                usdc.arm(address(swapper), calls[i]);
                _give(address(tkn), 1e18);
                vm.prank(holder);
                vm.expectRevert(reasons[i]);
                swapper.swap(routes, block.timestamp, false);
            }
        }
    }

    function test_pullsOnlyFromTheCaller() public {
        tkn.mint(stranger, 1e18);
        vm.prank(stranger);
        tkn.approve(address(swapper), type(uint256).max);
        ImmutableSwapper.Route[] memory routes = _routes(_direct(V3, address(tkn), 1e18));
        vm.prank(holder);
        vm.expectRevert(abi.encodeWithSelector(ImmutableSwapper.TokenCallFailed.selector, address(tkn)));
        swapper.swap(routes, block.timestamp, false);
        assertEq(tkn.balanceOf(stranger), 1e18);
    }

    function test_strayTokensAreNeverPaidOut() public {
        usdc.mint(address(swapper), 5e6);
        tkn.mint(address(swapper), 7e18);
        _give(address(tkn), 1e18);
        (ImmutableSwapper.Result[] memory results, uint256 paid,) = _swap(_routes(_direct(V3, address(tkn), 1e18)));
        assertEq(results[0].amountIn, 1e18);
        assertEq(paid, 0.99e18);
        assertEq(usdc.balanceOf(holder), 0.99e18);
        assertEq(usdc.balanceOf(address(swapper)), 5e6);
        assertEq(tkn.balanceOf(address(swapper)), 7e18);
    }

    function test_feeOnTransfer_worksThroughClassicPools() public {
        tkn.setTax(100);
        ImmutableSwapper.Route memory r = _direct(HYDREX_CLASSIC, address(tkn), 1e18);
        uint256 expected = MockClassicPool(r.hops[0].pool).getAmountOut(0.9801e18, address(tkn)) - 1;
        _give(address(tkn), 1e18);
        (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(r));
        assertEq(results[0].amountIn, 0.99e18);
        assertEq(results[0].amountOut, expected);
    }

    function test_feeOnTransfer_revertsThroughConcentratedAndV4Pools() public {
        tkn.setTax(100);
        _expectRouteRevert(_direct(ALGEBRA, address(tkn), 1e18), bytes("IIA"));
        _expectRouteRevert(_direct(V4, address(tkn), 1e18), bytes("CurrencyNotSettled"));
    }

    function test_tokens_withoutReturnValueOrThatRevert() public {
        tkn.setNoReturn(true);
        _give(address(tkn), 1e18);
        (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(_direct(V3, address(tkn), 1e18)));
        assertTrue(results[0].done);

        tkn.setNoReturn(false);
        tkn.setReverts(true);
        _expectRouteRevert(
            _direct(V3, address(tkn), 1e18),
            abi.encodeWithSelector(ImmutableSwapper.TokenCallFailed.selector, address(tkn))
        );
    }

    function testFuzz_feeMinimumsAndBalances(uint256 seed, uint256[3] memory amounts, uint256 n) public {
        n = bound(n, 1, 3);
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](n);
        for (uint256 i; i < n; ++i) {
            MockToken t = new MockToken(18);
            amounts[i] = bound(amounts[i], 1, 1e27);
            ImmutableSwapper.Exchange e = ImmutableSwapper.Exchange(uint256(keccak256(abi.encode(seed, i))) % EXCHANGES);
            routes[i] = _direct(e, address(t), amounts[i]);
            _give(address(t), amounts[i]);
        }
        ImmutableSwapper.Result[] memory quoted = _quote(routes);
        uint256 expectedPaid;
        uint256 expectedFee;
        for (uint256 i; i < n; ++i) {
            if (!quoted[i].done) continue;
            uint256 paid = quoted[i].amountOut - quoted[i].fee;
            // Some minimums are met exactly, others missed by one unit.
            routes[i].minPaid = paid + (uint256(keccak256(abi.encode(seed, i, "min"))) % 2);
            if (routes[i].minPaid > paid) continue;
            expectedPaid += paid;
            expectedFee += quoted[i].fee;
        }

        vm.prank(holder);
        (ImmutableSwapper.Result[] memory results, uint256 paidOut, uint256 fee) =
            swapper.swap(routes, block.timestamp, true);

        uint256 sum;
        for (uint256 i; i < n; ++i) {
            if (!results[i].done) {
                assertEq(IERC20(routes[i].token).balanceOf(holder), amounts[i]);
                continue;
            }
            assertEq(results[i].fee, results[i].amountOut / 100);
            assertGe(results[i].amountOut - results[i].fee, routes[i].minPaid);
            assertEq(IERC20(routes[i].token).balanceOf(holder), 0);
            assertEq(IERC20(routes[i].token).balanceOf(address(swapper)), 0);
            sum += results[i].amountOut;
        }
        assertEq(paidOut, expectedPaid);
        assertEq(fee, expectedFee);
        assertEq(paidOut + fee, sum);
        assertEq(usdc.balanceOf(holder), paidOut);
        assertEq(usdc.balanceOf(treasury), fee);
        assertEq(usdc.balanceOf(address(swapper)), 0);
    }

    // Gives the holder the route's token, and expects the route to revert with reason, with skipFailed off.
    function _expectRouteRevert(ImmutableSwapper.Route memory r, bytes memory reason) internal {
        if (r.token != address(0)) _give(r.token, r.amount);
        vm.prank(holder);
        vm.expectRevert(reason);
        swapper.swap(_routes(r), block.timestamp, false);
    }
}

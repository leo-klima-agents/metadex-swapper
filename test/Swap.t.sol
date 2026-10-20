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
    function _expected(ImmutableSwapper.Exchange e, address pool, address token, uint256 amount)
        internal
        view
        returns (uint256)
    {
        if (e == UNISWAP_V4 || _isConcentrated(e)) return amount;
        uint256 out = MockClassicPool(pool).getAmountOut(amount, token);
        return e == HYDREX_CLASSIC && out != 0 ? out - 1 : out;
    }

    function _assertEmpty(address token) internal view {
        assertEq(IERC20(token).balanceOf(address(swapper)), 0, "swapper keeps nothing");
        assertEq(usdc.balanceOf(address(swapper)), 0, "swapper keeps no USDC");
    }

    function test_oneHop_eachExchange() public {
        for (uint256 i; i < EXCHANGES; ++i) {
            ImmutableSwapper.Exchange e = ImmutableSwapper.Exchange(i);
            MockToken t = new MockToken();
            ImmutableSwapper.Route memory r = _direct(e, address(t), 1e18);
            uint256 expected = _expected(e, r.hops[0].pool, address(t), 1e18);
            ImmutableSwapper.Result[] memory quoted = _quote(_routes(r));
            _give(address(t), 1e18);
            uint256 holderBefore = usdc.balanceOf(holder);
            uint256 treasuryBefore = usdc.balanceOf(treasury);

            (ImmutableSwapper.Result[] memory results, uint256 paid, uint256 fee) = _swap(_routes(r));

            assertEq(abi.encode(quoted[0]), abi.encode(results[0]), "quote matches swap");
            assertTrue(results[0].done);
            assertEq(results[0].amountIn, 1e18);
            assertEq(results[0].amountOut, expected);
            assertEq(fee, expected / 100);
            assertEq(paid, expected - expected / 100);
            assertEq(usdc.balanceOf(holder) - holderBefore, paid);
            assertEq(usdc.balanceOf(treasury) - treasuryBefore, fee);
            assertEq(t.balanceOf(holder), 0);
            _assertEmpty(address(t));
        }
    }

    function test_twoHops_everyPairOfExchanges() public {
        address[EXCHANGES] memory first;
        address[EXCHANGES] memory second;
        for (uint256 i; i < EXCHANGES; ++i) {
            first[i] = _pool(ImmutableSwapper.Exchange(i), address(tkn), address(weth));
            second[i] = _pool(ImmutableSwapper.Exchange(i), address(weth), address(usdc));
        }
        for (uint256 i; i < EXCHANGES; ++i) {
            for (uint256 j; j < EXCHANGES; ++j) {
                ImmutableSwapper.Route memory r = _route(
                    address(tkn),
                    1e18,
                    _hops(
                        _hop(ImmutableSwapper.Exchange(i), first[i], address(weth)),
                        _hop(ImmutableSwapper.Exchange(j), second[j], address(usdc))
                    )
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
        address pool = _pool(UNISWAP_V3, address(usdc), address(weth), 2, 1);
        address other = _pool(UNISWAP_V3, address(tkn), address(weth));
        ImmutableSwapper.Route[] memory routes =
            _routes(_route(address(usdc), 1e6, _hops(_hop(UNISWAP_V3, pool, address(weth)))));
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

        routes = _routes(
            _route(
                address(tkn), 1e18, _hops(_hop(UNISWAP_V3, other, address(weth)), _hop(UNISWAP_V3, pool, address(usdc)))
            )
        );
        vm.expectRevert(abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0));
        wethSwapper.swap(routes, block.timestamp, false);
        routes = _routes(_route(address(weth), 1e18, _hops(_hop(UNISWAP_V3, pool, address(usdc)))));
        vm.expectRevert(abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0));
        wethSwapper.swap(routes, block.timestamp, false);
        vm.stopPrank();
    }

    function test_threeHops_mixed() public {
        address p1 = _pool(HYDREX_ALGEBRA, address(tkn), address(weth), 2, 1);
        address p2 = _pool(AERODROME_CLASSIC, address(weth), address(cbbtc), 1, 3);
        address p3 = _pool(AERO_STABLE, address(cbbtc), address(usdc), 5, 1);
        ImmutableSwapper.Route memory r = _route(
            address(tkn),
            1e18,
            _hops(
                _hop(HYDREX_ALGEBRA, p1, address(weth)),
                _hop(AERODROME_CLASSIC, p2, address(cbbtc)),
                _hop(AERO_STABLE, p3, address(usdc))
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

    function test_aero_quotesAndSwapsWithTheTotalFee() public {
        ImmutableSwapper.Route memory r = _direct(AERO_VOLATILE, address(tkn), 1e18);
        MockClassicPool pool = MockClassicPool(r.hops[0].pool);
        pool.setMevTax(500);
        uint256 expected = pool.getAmountOutWithTotalFee(1e18, address(tkn));
        assertLt(expected, pool.getAmountOut(1e18, address(tkn)));
        ImmutableSwapper.Result[] memory quoted = _quote(_routes(r));
        _give(address(tkn), 1e18);

        (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(r));

        assertEq(quoted[0].amountOut, expected);
        assertEq(results[0].amountOut, expected);
    }

    function test_v4_twoHopsInOneUnlock() public {
        _pool(UNISWAP_V4, address(tkn), address(weth), 3, 1);
        _pool(UNISWAP_V4, address(weth), address(usdc), 1, 2);
        ImmutableSwapper.Route memory r = _route(
            address(tkn),
            1e18,
            _hops(_hop(UNISWAP_V4, address(0), address(weth)), _hop(UNISWAP_V4, address(0), address(usdc)))
        );
        _give(address(tkn), 1e18);

        vm.expectCall(address(manager), abi.encodeWithSelector(IPoolManager.unlock.selector), 1);
        vm.expectCall(address(manager), abi.encodeWithSelector(IPoolManager.take.selector), 1);
        (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(r));

        assertEq(results[0].amountOut, 1.5e18);
        assertEq(manager.swappedKeys().length, 2);
        _assertEmpty(address(tkn));
        assertEq(weth.balanceOf(address(swapper)), 0);
    }

    function test_v4_nativeEthBetweenTwoHops() public {
        _pool(UNISWAP_V4, address(tkn), ETH, 2, 1);
        _pool(UNISWAP_V4, ETH, address(usdc), 3, 1);
        ImmutableSwapper.Route memory r = _route(
            address(tkn), 1e18, _hops(_hop(UNISWAP_V4, address(0), ETH), _hop(UNISWAP_V4, address(0), address(usdc)))
        );
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
        address pool = _pool(UNISWAP_V3, address(tkn), address(usdc));
        _pool(UNISWAP_V4, ETH, address(usdc));

        ImmutableSwapper.Route memory r =
            _route(address(tkn), 1e18, _hops(_hop(UNISWAP_V3, pool, ETH), _hop(UNISWAP_V4, address(0), address(usdc))));
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NativeOutsideV4.selector, 0, 0));

        r = _route(address(tkn), 1e18, _hops(_hop(UNISWAP_V4, address(0), ETH), _hop(UNISWAP_V3, pool, address(usdc))));
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NativeOutsideV4.selector, 0, 0));

        r = _route(ETH, 1e18, _hops(_hop(UNISWAP_V4, address(0), address(usdc))));
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0));

        r = _route(address(tkn), 1e18, _hops(_hop(UNISWAP_V4, address(0), ETH)));
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0));
    }

    function test_v4_runBackToItsFirstToken() public {
        _pool(UNISWAP_V4, address(tkn), address(weth));
        address pool = _pool(UNISWAP_V3, address(tkn), address(usdc));
        ImmutableSwapper.Route memory r = _route(
            address(tkn),
            1e18,
            _hops(
                _hop(UNISWAP_V4, address(0), address(weth)),
                _hop(UNISWAP_V4, address(0), address(tkn)),
                _hop(UNISWAP_V3, pool, address(usdc))
            )
        );
        bytes memory reason = abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 1);
        assertEq(_quote(_routes(r))[0].reason, reason);
        _expectRouteRevert(r, reason);
    }

    function test_v4_hopWithAPoolReverts() public {
        _pool(UNISWAP_V4, address(tkn), address(usdc));
        ImmutableSwapper.Route memory r = _route(address(tkn), 1e18, _hops(_hop(UNISWAP_V4, address(1), address(usdc))));
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NotExchangePool.selector, UNISWAP_V4, address(1)));
    }

    function test_v4_keyIsTheHopsFeeAndTickSpacingWithNoHooks() public {
        (address c0, address c1) =
            address(tkn) < address(usdc) ? (address(tkn), address(usdc)) : (address(usdc), address(tkn));
        IPoolManager.PoolKey memory key = IPoolManager.PoolKey(c0, c1, 500, 10, address(0));
        manager.initialize(key, 1, 1);
        usdc.mint(address(manager), DEEP);
        _give(address(tkn), 1e18);
        _swap(
            _routes(
                _route(address(tkn), 1e18, _hops(ImmutableSwapper.Hop(UNISWAP_V4, address(0), address(usdc), 500, 10)))
            )
        );
        assertEq(abi.encode(manager.swappedKeys()[0]), abi.encode(key));

        key = _key(c0, c1);
        key.hooks = makeAddr("hooks");
        manager.initialize(key, 1, 1);
        _expectRouteRevert(
            _route(address(tkn), 1e18, _hops(_hop(UNISWAP_V4, address(0), address(usdc)))), bytes("PoolNotInitialized")
        );
    }

    function test_poolCheck_refusesAnotherExchangesPool() public {
        for (uint256 i; i < uint256(UNISWAP_V4); ++i) {
            ImmutableSwapper.Exchange e = ImmutableSwapper.Exchange(i);
            address pool = _pool(ImmutableSwapper.Exchange((i + 1) % uint256(UNISWAP_V4)), address(tkn), address(usdc));
            ImmutableSwapper.Route memory r = _route(address(tkn), 1e18, _hops(_hop(e, pool, address(usdc))));
            _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NotExchangePool.selector, e, pool));
        }
    }

    function test_poolCheck_refusesAPoolForOtherTokens() public {
        for (uint256 i; i < uint256(UNISWAP_V4); ++i) {
            ImmutableSwapper.Exchange e = ImmutableSwapper.Exchange(i);
            address pool = _pool(e, address(weth), address(usdc));
            ImmutableSwapper.Route memory r = _route(address(tkn), 1e18, _hops(_hop(e, pool, address(usdc))));
            _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NotExchangePool.selector, e, pool));
        }
    }

    function test_poolCheck_refusesAddressesNoFactoryMade() public {
        address[3] memory bad = [makeAddr("nobody"), address(usdc), address(0)];
        for (uint256 i; i < uint256(UNISWAP_V4); ++i) {
            ImmutableSwapper.Exchange e = ImmutableSwapper.Exchange(i);
            _pool(e, address(tkn), address(usdc));
            for (uint256 j; j < bad.length; ++j) {
                ImmutableSwapper.Route memory r = _route(address(tkn), 1e18, _hops(_hop(e, bad[j], address(usdc))));
                _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NotExchangePool.selector, e, bad[j]));
            }
        }
    }

    function test_poolCheck_uniswapV3AsksTheFactoryAtTheHopsFee() public {
        ImmutableSwapper.Route memory r = _direct(UNISWAP_V3, address(tkn), 1e18);
        r.hops[0].fee = 3000;
        _expectRouteRevert(
            r, abi.encodeWithSelector(ImmutableSwapper.NotExchangePool.selector, UNISWAP_V3, r.hops[0].pool)
        );
    }

    function test_severalRoutes_sameTokenTwice() public {
        ImmutableSwapper.Route memory a = _direct(UNISWAP_V3, address(tkn), 1e18);
        ImmutableSwapper.Route memory b = _direct(AERODROME_SLIPSTREAM, address(tkn), 2e18);
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

    function test_severalRoutes_anyNumber() public {
        uint256 n = 40;
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](n);
        for (uint256 i; i < n; ++i) {
            MockToken t = new MockToken();
            routes[i] = _direct(ImmutableSwapper.Exchange(i % EXCHANGES), address(t), 1e18);
            _give(address(t), 1e18);
        }
        (ImmutableSwapper.Result[] memory results,,) = _swap(routes);
        for (uint256 i; i < n; ++i) {
            assertTrue(results[i].done);
        }
    }

    function test_hopCount() public {
        bytes memory reason = abi.encodeWithSelector(ImmutableSwapper.BadHopCount.selector, 0);
        _expectRouteRevert(_route(address(tkn), 1e18, new ImmutableSwapper.Hop[](0)), reason);
        _expectRouteRevert(_route(address(tkn), 1e18, new ImmutableSwapper.Hop[](swapper.MAX_HOPS() + 1)), reason);
    }

    function test_skipFailed_skipsTheRouteAndPaysTheOthers() public {
        MockToken bad = new MockToken();
        ImmutableSwapper.Route memory a = _direct(UNISWAP_V3, address(tkn), 1e18);
        ImmutableSwapper.Route memory b = _direct(UNISWAP_V2, address(bad), 1e18);
        b.minPaid = 1e18;
        ImmutableSwapper.Route memory c = _direct(HYDREX_ALGEBRA, address(weth), 2e18);
        _give(address(tkn), 1e18);
        _give(address(bad), 1e18);
        _give(address(weth), 2e18);
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](3);
        (routes[0], routes[1], routes[2]) = (a, b, c);
        uint256 out = MockClassicPool(b.hops[0].pool).getAmountOut(1e18, address(bad));
        bytes memory reason =
            abi.encodeWithSelector(ImmutableSwapper.TooLittle.selector, 1, out - out / 100, uint256(1e18));

        vm.expectEmit(address(swapper));
        emit ImmutableSwapper.RouteSwapped(holder, 0, address(tkn), 1e18, 1e18);
        vm.expectEmit(address(swapper));
        emit ImmutableSwapper.RouteFailed(holder, 1, address(bad), reason);
        vm.expectEmit(address(swapper));
        emit ImmutableSwapper.RouteSwapped(holder, 2, address(weth), 2e18, 2e18);
        vm.expectEmit(address(swapper));
        emit ImmutableSwapper.Swapped(holder, 3e18 - 3e16, 3e16);
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

    function test_fee_onePercentOfEachRouteRoundedDown() public {
        (uint256 x, uint256 y) = (199, 12_345);
        ImmutableSwapper.Route memory a = _direct(UNISWAP_V3, address(tkn), x);
        ImmutableSwapper.Route memory b = _direct(UNISWAP_V3, address(weth), y);
        _give(address(tkn), x);
        _give(address(weth), y);

        (, uint256 paid, uint256 fee) = _swap(_routes(a, b));

        assertEq(fee, x / 100 + y / 100);
        assertEq(paid + fee, x + y);
        assertEq(usdc.balanceOf(treasury), fee);
        assertEq(usdc.balanceOf(holder), paid);
    }

    function test_fee_noTransferToTheTreasuryWhenZero() public {
        _give(address(tkn), 99);
        vm.expectCall(address(usdc), abi.encodeWithSelector(IERC20.transfer.selector, treasury), 0);
        (, uint256 paid, uint256 fee) = _swap(_routes(_direct(UNISWAP_V3, address(tkn), 99)));
        assertEq(fee, 0);
        assertEq(paid, 99);
    }

    function test_minPaid_exactlyMetAndOneUnitShort() public {
        ImmutableSwapper.Route memory r = _direct(UNISWAP_V3, address(tkn), 1e18);
        r.minPaid = 0.99e18;
        _give(address(tkn), 1e18);
        (, uint256 paid,) = _swap(_routes(r));
        assertEq(paid, 0.99e18);

        r.minPaid = 0.99e18 + 1;
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.TooLittle.selector, 0, 0.99e18, 0.99e18 + 1));
    }

    function test_deadline_metAndPassed() public {
        ImmutableSwapper.Route[] memory routes = _routes(_direct(UNISWAP_V3, address(tkn), 1e18));
        _give(address(tkn), 1e18);
        vm.prank(holder);
        vm.expectRevert(ImmutableSwapper.Expired.selector);
        swapper.swap(routes, block.timestamp - 1, false);
        vm.prank(holder);
        swapper.swap(routes, block.timestamp, false);
    }

    function test_maxAmount_takesTheSmallerOfBalanceAndAllowance() public {
        ImmutableSwapper.Route memory r = _direct(UNISWAP_V3, address(tkn), type(uint256).max);
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

    function test_path_outputTokenIn() public {
        address pool = _pool(UNISWAP_V3, address(usdc), address(weth));
        _expectRouteRevert(
            _route(address(usdc), 1e6, _hops(_hop(UNISWAP_V3, pool, address(usdc)))),
            abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0)
        );
    }

    function test_path_outputTokenMidRoute() public {
        address p1 = _pool(UNISWAP_V3, address(tkn), address(usdc));
        address p2 = _pool(UNISWAP_V3, address(usdc), address(weth));
        ImmutableSwapper.Route memory r =
            _route(address(tkn), 1e18, _hops(_hop(UNISWAP_V3, p1, address(usdc)), _hop(UNISWAP_V3, p2, address(weth))));
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0));
    }

    function test_path_lastTokenNotOutput() public {
        address pool = _pool(UNISWAP_V3, address(tkn), address(weth));
        _expectRouteRevert(
            _route(address(tkn), 1e18, _hops(_hop(UNISWAP_V3, pool, address(weth)))),
            abi.encodeWithSelector(ImmutableSwapper.BadPath.selector, 0, 0)
        );
    }

    function test_partialFill_reverts() public {
        ImmutableSwapper.Route memory r = _direct(AERODROME_SLIPSTREAM, address(tkn), 1e18);
        MockConcentratedPool(r.hops[0].pool).misbehave({fillBps_: 9000, extra_: 0, wrongSide_: false, callbacks_: 1});
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.PartialFill.selector, r.hops[0].pool));

        r = _direct(UNISWAP_V4, address(weth), 1e18);
        manager.setFill(9000);
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.PartialFill.selector, address(manager)));
    }

    function test_noOutput_reverts() public {
        _expectRouteRevert(
            _direct(UNISWAP_V2, address(tkn), 1), abi.encodeWithSelector(ImmutableSwapper.NoOutput.selector, 0, 0)
        );
        address pool = _pool(UNISWAP_V3, address(weth), address(usdc), 1, 1e18);
        _expectRouteRevert(
            _route(address(weth), 1, _hops(_hop(UNISWAP_V3, pool, address(usdc)))),
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

        ImmutableSwapper.Route memory r = _direct(HYDREX_ALGEBRA, address(tkn), 1e18);
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
        ImmutableSwapper.Route memory r = _direct(UNISWAP_V3, address(tkn), 1e18);
        MockConcentratedPool(r.hops[0].pool).misbehave({fillBps_: 10_000, extra_: 0, wrongSide_: false, callbacks_: 2});
        _expectRouteRevert(r, abi.encodeWithSelector(ImmutableSwapper.NotExpectedCaller.selector, r.hops[0].pool));
    }

    function test_callbacks_onlyTheHopsTokenAndAmount() public {
        ImmutableSwapper.Route memory r = _direct(HYDREX_ALGEBRA, address(tkn), 1e18);
        MockConcentratedPool pool = MockConcentratedPool(r.hops[0].pool);
        bytes memory partialFill = abi.encodeWithSelector(ImmutableSwapper.PartialFill.selector, address(pool));
        pool.misbehave({fillBps_: 10_000, extra_: 0, wrongSide_: true, callbacks_: 1});
        _expectRouteRevert(r, partialFill);
        pool.misbehave({fillBps_: 10_000, extra_: 1, wrongSide_: false, callbacks_: 1});
        _expectRouteRevert(r, partialFill);
    }

    function test_runRoute_onlyTheSwapperItself() public {
        ImmutableSwapper.Route memory r = _direct(UNISWAP_V3, address(tkn), 1e18);
        vm.prank(stranger);
        vm.expectRevert(ImmutableSwapper.OnlySelf.selector);
        swapper.runRoute(stranger, 0, r);
    }

    function test_reentrancy_throughATokenHook() public {
        ImmutableSwapper.Exchange[4] memory es = [UNISWAP_V2, UNISWAP_V3, HYDREX_ALGEBRA, UNISWAP_V4];
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
                usdc.arm(address(swapper), calls[i]);
                _give(address(tkn), 1e18);
                vm.prank(holder);
                vm.expectRevert(reasons[i]);
                swapper.swap(routes, block.timestamp, false);
            }
        }
    }

    function test_reentrancy_swapInsideAQuote() public {
        ImmutableSwapper.Route[] memory routes = _routes(_direct(UNISWAP_V3, address(tkn), 1e18));
        tkn.mint(holder, 1e18);
        usdc.arm(address(swapper), abi.encodeCall(ImmutableSwapper.swap, (routes, block.timestamp, false)));

        ImmutableSwapper.Result[] memory quoted = _quote(routes);

        assertEq(quoted[0].reason, abi.encodeWithSelector(ImmutableSwapper.Reentrancy.selector));
    }

    function test_pullsOnlyFromTheCaller() public {
        tkn.mint(stranger, 1e18);
        vm.prank(stranger);
        tkn.approve(address(swapper), type(uint256).max);
        ImmutableSwapper.Route[] memory routes = _routes(_direct(UNISWAP_V3, address(tkn), 1e18));
        vm.prank(holder);
        vm.expectRevert(abi.encodeWithSelector(ImmutableSwapper.TokenCallFailed.selector, address(tkn)));
        swapper.swap(routes, block.timestamp, false);
        assertEq(tkn.balanceOf(stranger), 1e18);
    }

    function test_strayTokensAreNeverPaidOut() public {
        usdc.mint(address(swapper), 5e6);
        tkn.mint(address(swapper), 7e18);
        _give(address(tkn), 1e18);
        (ImmutableSwapper.Result[] memory results, uint256 paid,) =
            _swap(_routes(_direct(UNISWAP_V3, address(tkn), 1e18)));
        assertEq(results[0].amountIn, 1e18);
        assertEq(paid, 0.99e18);
        assertEq(usdc.balanceOf(holder), 0.99e18);
        assertEq(usdc.balanceOf(address(swapper)), 5e6);
        assertEq(tkn.balanceOf(address(swapper)), 7e18);
    }

    function test_classic_syncsThePoolFirst() public {
        ImmutableSwapper.Route memory r = _direct(AERODROME_CLASSIC, address(tkn), 1e18);
        MockClassicPool pool = MockClassicPool(r.hops[0].pool);
        tkn.mint(address(pool), 5e18);
        usdc.mint(address(pool), 5e18);
        uint256 snap = vm.snapshotState();
        pool.sync();
        uint256 expected = pool.getAmountOut(1e18, address(tkn));
        vm.revertToState(snap);
        _give(address(tkn), 1e18);

        vm.expectCall(address(pool), abi.encodeCall(MockClassicPool.sync, ()));
        (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(r));
        assertEq(results[0].amountOut, expected);

        tkn.mint(address(pool), 5e18);
        r.amount = type(uint256).max;
        vm.prank(holder);
        vm.expectRevert(abi.encodeWithSelector(ImmutableSwapper.NoOutput.selector, 0, 0));
        swapper.swap(_routes(r), block.timestamp, false);
    }

    function test_feeOnTransfer_worksThroughClassicPools() public {
        tkn.setTax(100);
        ImmutableSwapper.Route memory r = _direct(HYDREX_CLASSIC, address(tkn), 1e18);
        uint256 expected = MockClassicPool(r.hops[0].pool).getAmountOut(1e18 * 99 / 100 * 99 / 100, address(tkn)) - 1;
        _give(address(tkn), 1e18);
        (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(r));
        assertEq(results[0].amountIn, 0.99e18);
        assertEq(results[0].amountOut, expected);
    }

    function test_feeOnTransfer_revertsThroughConcentratedAndV4Pools() public {
        tkn.setTax(100);
        _expectRouteRevert(_direct(HYDREX_ALGEBRA, address(tkn), 1e18), bytes("IIA"));
        _expectRouteRevert(_direct(UNISWAP_V4, address(tkn), 1e18), bytes("CurrencyNotSettled"));
    }

    function test_tokens_returnValues() public {
        tkn.setReturnData("");
        _give(address(tkn), 1e18);
        (ImmutableSwapper.Result[] memory results,,) = _swap(_routes(_direct(UNISWAP_V3, address(tkn), 1e18)));
        assertTrue(results[0].done);

        bytes memory failed = abi.encodeWithSelector(ImmutableSwapper.TokenCallFailed.selector, address(tkn));
        bytes[3] memory bad = [abi.encode(false), abi.encode(uint256(2)), bytes(hex"01")];
        for (uint256 i; i < bad.length; ++i) {
            tkn.setReturnData(bad[i]);
            _expectRouteRevert(_direct(UNISWAP_V3, address(tkn), 1e18), failed);
        }
        tkn.setReturnData(abi.encode(true));
        tkn.setReverts(true);
        _expectRouteRevert(_direct(UNISWAP_V3, address(tkn), 1e18), failed);
    }

    function testFuzz_feeMinimumsAndBalances(
        uint8[3] memory exchanges,
        uint256[3] memory amounts,
        bool[3] memory missByOne,
        uint256 n
    ) public {
        n = bound(n, 1, 3);
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](n);
        for (uint256 i; i < n; ++i) {
            MockToken t = new MockToken();
            amounts[i] = bound(amounts[i], 1, 1e27);
            routes[i] =
                _direct(ImmutableSwapper.Exchange(bound(exchanges[i], 0, EXCHANGES - 1)), address(t), amounts[i]);
            _give(address(t), amounts[i]);
        }
        ImmutableSwapper.Result[] memory quoted = _quote(routes);
        uint256 expectedPaid;
        uint256 expectedFee;
        for (uint256 i; i < n; ++i) {
            if (!quoted[i].done) continue;
            uint256 routeFee = quoted[i].amountOut / 100;
            uint256 routePaid = quoted[i].amountOut - routeFee;
            routes[i].minPaid = missByOne[i] ? routePaid + 1 : routePaid;
            if (missByOne[i]) continue;
            expectedPaid += routePaid;
            expectedFee += routeFee;
        }

        vm.prank(holder);
        (ImmutableSwapper.Result[] memory results, uint256 paid, uint256 fee) =
            swapper.swap(routes, block.timestamp, true);

        uint256 sum;
        for (uint256 i; i < n; ++i) {
            if (!results[i].done) {
                assertEq(IERC20(routes[i].token).balanceOf(holder), amounts[i]);
                continue;
            }
            assertGe(results[i].amountOut - results[i].amountOut / 100, routes[i].minPaid);
            assertEq(IERC20(routes[i].token).balanceOf(holder), 0);
            assertEq(IERC20(routes[i].token).balanceOf(address(swapper)), 0);
            sum += results[i].amountOut;
        }
        assertEq(paid, expectedPaid);
        assertEq(fee, expectedFee);
        assertEq(paid + fee, sum);
        assertEq(usdc.balanceOf(holder), paid);
        assertEq(usdc.balanceOf(treasury), fee);
        assertEq(usdc.balanceOf(address(swapper)), 0);
    }

    function _expectRouteRevert(ImmutableSwapper.Route memory r, bytes memory reason) internal {
        if (r.token != address(0)) _give(r.token, r.amount);
        vm.prank(holder);
        vm.expectRevert(reason);
        swapper.swap(_routes(r), block.timestamp, false);
    }
}

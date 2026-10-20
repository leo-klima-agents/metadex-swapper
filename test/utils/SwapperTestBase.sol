// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Test} from "forge-std/Test.sol";

import {ImmutableSwapper} from "../../src/ImmutableSwapper.sol";
import {IPoolManager} from "../../src/interfaces/IPoolManager.sol";
import {MockClassicPool} from "../mocks/MockClassicPool.sol";
import {MockConcentratedPool} from "../mocks/MockConcentratedPool.sol";
import {MockFactory} from "../mocks/MockFactory.sol";
import {MockPoolManager} from "../mocks/MockPoolManager.sol";
import {MockToken} from "../mocks/MockToken.sol";

abstract contract SwapperTestBase is Test {
    ImmutableSwapper.Exchange internal constant HYDREX_ALGEBRA = ImmutableSwapper.Exchange.HydrexAlgebra;
    ImmutableSwapper.Exchange internal constant HYDREX_CLASSIC = ImmutableSwapper.Exchange.HydrexClassic;
    ImmutableSwapper.Exchange internal constant AERO_VOLATILE = ImmutableSwapper.Exchange.AeroVolatile;
    ImmutableSwapper.Exchange internal constant AERO_STABLE = ImmutableSwapper.Exchange.AeroStable;
    ImmutableSwapper.Exchange internal constant AERO_SLIPSTREAM = ImmutableSwapper.Exchange.AeroSlipstream;
    ImmutableSwapper.Exchange internal constant AERODROME_CLASSIC = ImmutableSwapper.Exchange.AerodromeClassic;
    ImmutableSwapper.Exchange internal constant AERODROME_SLIPSTREAM = ImmutableSwapper.Exchange.AerodromeSlipstream;
    ImmutableSwapper.Exchange internal constant AERODROME_SLIPSTREAM_2 = ImmutableSwapper.Exchange.AerodromeSlipstream2;
    ImmutableSwapper.Exchange internal constant AERODROME_SLIPSTREAM_3 = ImmutableSwapper.Exchange.AerodromeSlipstream3;
    ImmutableSwapper.Exchange internal constant UNISWAP_V2 = ImmutableSwapper.Exchange.UniswapV2;
    ImmutableSwapper.Exchange internal constant UNISWAP_V3 = ImmutableSwapper.Exchange.UniswapV3;
    ImmutableSwapper.Exchange internal constant UNISWAP_V4 = ImmutableSwapper.Exchange.UniswapV4;

    uint256 internal constant EXCHANGES = 12;
    uint256 internal constant DEEP = 1e30;
    uint24 internal constant V3_FEE = 500;
    uint24 internal constant V4_FEE = 3000;
    int24 internal constant V4_TICK_SPACING = 60;
    address internal constant ETH = address(0);

    address internal holder = makeAddr("holder");
    address internal stranger = makeAddr("stranger");
    address internal treasury;

    MockToken internal usdc;
    MockToken internal weth;
    MockToken internal cbbtc;
    MockToken internal tkn;
    MockFactory[EXCHANGES - 1] internal factories;
    MockPoolManager internal manager;
    ImmutableSwapper internal swapper;

    function setUp() public virtual {
        vm.warp(1_800_000_000);
        usdc = new MockToken();
        weth = new MockToken();
        cbbtc = new MockToken();
        tkn = new MockToken();
        for (uint256 i; i < EXCHANGES - 1; ++i) {
            factories[i] = new MockFactory();
        }
        manager = new MockPoolManager();
        swapper = new ImmutableSwapper(address(usdc), _exchanges());
        treasury = swapper.TREASURY();
    }

    function _exchanges() internal view returns (address[EXCHANGES] memory list) {
        for (uint256 i; i < EXCHANGES - 1; ++i) {
            list[i] = address(factories[i]);
        }
        list[EXCHANGES - 1] = address(manager);
    }

    function _direct(ImmutableSwapper.Exchange e, address token, uint256 amount)
        internal
        returns (ImmutableSwapper.Route memory)
    {
        address pool = _pool(e, token, address(usdc));
        return _route(token, amount, _hops(_hop(e, pool, address(usdc))));
    }

    function _route(address token, uint256 amount, ImmutableSwapper.Hop[] memory hops)
        internal
        pure
        returns (ImmutableSwapper.Route memory)
    {
        return ImmutableSwapper.Route(token, amount, 0, hops);
    }

    function _routes(ImmutableSwapper.Route memory a) internal pure returns (ImmutableSwapper.Route[] memory r) {
        r = new ImmutableSwapper.Route[](1);
        r[0] = a;
    }

    function _routes(ImmutableSwapper.Route memory a, ImmutableSwapper.Route memory b)
        internal
        pure
        returns (ImmutableSwapper.Route[] memory r)
    {
        r = new ImmutableSwapper.Route[](2);
        r[0] = a;
        r[1] = b;
    }

    function _isConcentrated(ImmutableSwapper.Exchange e) internal pure returns (bool) {
        return e == HYDREX_ALGEBRA || e == AERO_SLIPSTREAM || e == AERODROME_SLIPSTREAM || e == AERODROME_SLIPSTREAM_2
            || e == AERODROME_SLIPSTREAM_3 || e == UNISWAP_V3;
    }

    function _pool(ImmutableSwapper.Exchange e, address a, address b, uint256 num, uint256 den)
        internal
        returns (address pool)
    {
        if (e == UNISWAP_V4) {
            (address c0, address c1) = a < b ? (a, b) : (b, a);
            (uint256 n, uint256 d) = a < b ? (num, den) : (den, num);
            manager.initialize(_key(c0, c1), n, d);
            if (a != ETH) MockToken(a).mint(address(manager), DEEP);
            if (b != ETH) MockToken(b).mint(address(manager), DEEP);
            return address(0);
        }
        if (_isConcentrated(e)) {
            pool = address(new MockConcentratedPool(a, b, e == HYDREX_ALGEBRA, num, den));
            MockToken(a).mint(pool, DEEP);
            MockToken(b).mint(pool, DEEP);
        } else {
            MockClassicPool p = new MockClassicPool(a, b, e == UNISWAP_V2 ? 30 : 20);
            MockToken(a).mint(address(p), DEEP);
            MockToken(b).mint(address(p), DEEP * num / den);
            p.sync();
            pool = address(p);
        }
        factories[uint256(e)].list(pool, a, b, V3_FEE);
    }

    function _pool(ImmutableSwapper.Exchange e, address a, address b) internal returns (address) {
        return _pool(e, a, b, 1, 1);
    }

    function _key(address c0, address c1) internal pure returns (IPoolManager.PoolKey memory) {
        return IPoolManager.PoolKey(c0, c1, V4_FEE, V4_TICK_SPACING, address(0));
    }

    function _hop(ImmutableSwapper.Exchange e, address pool, address tokenOut)
        internal
        pure
        returns (ImmutableSwapper.Hop memory)
    {
        if (e == UNISWAP_V4) return ImmutableSwapper.Hop(e, pool, tokenOut, V4_FEE, V4_TICK_SPACING);
        return ImmutableSwapper.Hop(e, pool, tokenOut, e == UNISWAP_V3 ? V3_FEE : 0, 0);
    }

    function _hops(ImmutableSwapper.Hop memory a) internal pure returns (ImmutableSwapper.Hop[] memory h) {
        h = new ImmutableSwapper.Hop[](1);
        h[0] = a;
    }

    function _hops(ImmutableSwapper.Hop memory a, ImmutableSwapper.Hop memory b)
        internal
        pure
        returns (ImmutableSwapper.Hop[] memory h)
    {
        h = new ImmutableSwapper.Hop[](2);
        h[0] = a;
        h[1] = b;
    }

    function _hops(ImmutableSwapper.Hop memory a, ImmutableSwapper.Hop memory b, ImmutableSwapper.Hop memory c)
        internal
        pure
        returns (ImmutableSwapper.Hop[] memory h)
    {
        h = new ImmutableSwapper.Hop[](3);
        h[0] = a;
        h[1] = b;
        h[2] = c;
    }

    function _give(address token, uint256 amount) internal {
        MockToken(token).mint(holder, amount);
        vm.prank(holder);
        MockToken(token).approve(address(swapper), amount);
    }

    function _swap(ImmutableSwapper.Route[] memory routes)
        internal
        returns (ImmutableSwapper.Result[] memory results, uint256 paid, uint256 fee)
    {
        vm.prank(holder);
        return swapper.swap(routes, block.timestamp, false);
    }

    function _quote(ImmutableSwapper.Route[] memory routes) internal returns (ImmutableSwapper.Result[] memory) {
        vm.prank(holder);
        return swapper.quote(routes);
    }
}

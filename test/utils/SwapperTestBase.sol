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
        usdc = new MockToken(6);
        weth = new MockToken(18);
        cbbtc = new MockToken(8);
        tkn = new MockToken(18);
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

    function _all() internal pure returns (ImmutableSwapper.Exchange[] memory list) {
        list = new ImmutableSwapper.Exchange[](EXCHANGES);
        for (uint256 i; i < EXCHANGES; ++i) {
            list[i] = ImmutableSwapper.Exchange(i);
        }
    }

    function _isConcentrated(ImmutableSwapper.Exchange e) internal pure returns (bool) {
        return e == ImmutableSwapper.Exchange.HydrexAlgebra || e == ImmutableSwapper.Exchange.AeroSlipstream
            || e == ImmutableSwapper.Exchange.AerodromeSlipstream || e == ImmutableSwapper.Exchange.AerodromeSlipstream2
            || e == ImmutableSwapper.Exchange.AerodromeSlipstream3 || e == ImmutableSwapper.Exchange.UniswapV3;
    }

    // A pool of exchange e that pays num/den of b for each unit of a. Zero for Uniswap v4, whose pools are keys.
    function _pool(ImmutableSwapper.Exchange e, address a, address b, uint256 num, uint256 den)
        internal
        returns (address pool)
    {
        if (e == ImmutableSwapper.Exchange.UniswapV4) {
            (address c0, address c1) = a < b ? (a, b) : (b, a);
            (uint256 n, uint256 d) = a < b ? (num, den) : (den, num);
            manager.initialize(_key(c0, c1), n, d);
            if (a != ETH) MockToken(a).mint(address(manager), DEEP);
            if (b != ETH) MockToken(b).mint(address(manager), DEEP);
            return address(0);
        }
        if (_isConcentrated(e)) {
            pool =
                address(new MockConcentratedPool(a, b, V3_FEE, e == ImmutableSwapper.Exchange.HydrexAlgebra, num, den));
            MockToken(a).mint(pool, DEEP);
            MockToken(b).mint(pool, DEEP);
        } else {
            MockClassicPool p = new MockClassicPool(a, b, e == ImmutableSwapper.Exchange.UniswapV2 ? 30 : 20);
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
        if (e == ImmutableSwapper.Exchange.UniswapV4) {
            return ImmutableSwapper.Hop(e, pool, tokenOut, V4_FEE, V4_TICK_SPACING);
        }
        return ImmutableSwapper.Hop(e, pool, tokenOut, 0, 0);
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

    // A route of one hop to USDC, through a new pool of exchange e.
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

    // Mints amount of token to the holder, who approves exactly that.
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

    function _fee(uint256 usdcOut) internal pure returns (uint256) {
        return usdcOut / 100;
    }
}

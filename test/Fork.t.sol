// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {stdJson} from "forge-std/StdJson.sol";
import {Test, console} from "forge-std/Test.sol";

import {Deploy} from "../script/Deploy.s.sol";
import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";
import {IClassicPool} from "../src/interfaces/IClassicPool.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

interface IApprove {
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IAeroPoolFactory {
    function createPool(address tokenA, address tokenB) external returns (address);
    function implementation() external view returns (address);
}

interface ICLFactory {
    function createPool(address tokenA, address tokenB, int24 tickSpacing, uint160 sqrtPriceX96)
        external
        returns (address);
    function poolImplementation() external view returns (address);
}

interface IClassicMint {
    function mint(address to) external returns (uint256);
}

interface ICLPool {
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data)
        external
        returns (uint256, uint256);
}

interface ISlot0 {
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16, uint16, uint16, uint8, bool);
}

interface IOwned {
    function owner() external view returns (address);
}

interface ITimelock {
    function getMinDelay() external view returns (uint256);
}

interface IAeroModules {
    function feeModule() external view returns (address);
    function mevTaxModule() external view returns (address);
}

interface ISwapHooks {
    function defaultSwapHook() external view returns (address);
}

interface IAeroRegistry {
    function targetFactories() external view returns (address[] memory);
}

interface IAerodromeRegistry {
    function poolFactories() external view returns (address[] memory);
}

contract ForkTest is Test {
    using stdJson for string;

    uint256 internal constant TX_GAS_CAP = 2 ** 24;
    bytes32 internal constant IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
    address internal constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address internal constant TREASURY = 0x450c72de8c0079B49AcedF294a13011bd09D125B;
    address internal constant UNISWAP_V3_WETH_USDC = 0xd0b53D9277642d899DF5C87A3966A349A798F224;

    address internal constant HYDREX_PAIR_FACTORY_IMPL = 0x421656A4Fc9943a2A7997D6f4f6c04EB2E336d18;
    address internal constant HYDREX_PROXY_ADMIN = 0x6E25D241a3bA9E0278a296b398E9678E5ED8ad40;
    address internal constant HYDREX_TIMELOCK = 0xdF52b5A03E3F5a4178E4F63e8BC51abE691B898F;
    address internal constant ALGEBRA_OWNER = 0x74266f2b206D1359B83fc74949EF07176FB3AE03;
    address internal constant AERO_REGISTRY = 0x7b2A2c12dC5Ea2a31455952a05031C3E4BB28F3E;
    address internal constant AERODROME_REGISTRY = 0x5C3F18F06CC09CA1910767A34a20F771039E37C0;
    address internal constant AERO_VOLATILE_IMPL = 0x8B64A0B590815d54C11a4B49A82b0133c7f53f0E;
    address internal constant AERO_STABLE_IMPL = 0x37D232368a22126a9584C7FF7643f26B2E276Ac8;
    address internal constant AERO_CL_IMPL = 0x0Df9fc8730eeC048e9832B31B4bFf4351158e19B;
    address internal constant AERODROME_POOL_IMPL = 0xA4e46b4f701c62e14DF11B48dCe76A7d793CD6d7;
    address internal constant AERODROME_CL_IMPL = 0xeC8E5342B19977B4eF8892e02D8DAEcfa1315831;
    address internal constant AERODROME_CL_IMPL_2 = 0x942e97a4c6FdC38B4CD1c0298D37d81fDD8E5A16;
    address internal constant AERODROME_CL_IMPL_3 = 0xc770898522D2A9c8Da7A10D63989b6b58305B665;
    address internal constant AERO_VOLATILE_FEES = 0xEc4b9100C60B54579d44eA38165a152865840597;
    address internal constant AERO_VOLATILE_TAX = 0x1d52180B9049cb16f7db490bF1bB0ABEb992593d;
    address internal constant AERO_STABLE_FEES = 0x39CF8E719bae01C9ab6F9eA5b97DC7D74C76e422;
    address internal constant AERO_STABLE_TAX = 0xA9Af4985CD8456d9aFf3185c31d9D66e53184d7B;
    address internal constant AERO_SWAP_HOOK = 0xaAf164008441F112eB2858d9F7A2dB1B84b1E415;

    string internal fx;
    Deploy internal d;
    ImmutableSwapper internal swapper;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        vm.skip(bytes(rpc).length == 0);
        fx = vm.readFile("test/fixtures/fork.json");
        vm.createSelectFork(rpc, fx.readUint(".block"));
        assertEq(block.chainid, 8453);
        d = new Deploy();
        swapper = ImmutableSwapper(d.run());
    }

    function _pins() internal view returns (address[28] memory a, bytes32[28] memory h) {
        address[12] memory e = d.exchanges();
        for (uint256 i; i < e.length; ++i) {
            a[i] = e[i];
        }
        (a[12], a[13], a[14], a[15], a[16]) =
        (HYDREX_PAIR_FACTORY_IMPL, HYDREX_PROXY_ADMIN, AERO_VOLATILE_IMPL, AERO_STABLE_IMPL, AERO_CL_IMPL);
        (a[17], a[18], a[19], a[20], a[21]) =
        (AERODROME_POOL_IMPL, AERODROME_CL_IMPL, AERODROME_CL_IMPL_2, AERODROME_CL_IMPL_3, AERO_REGISTRY);
        (a[22], a[23], a[24], a[25], a[26], a[27]) =
        (AERODROME_REGISTRY, AERO_VOLATILE_FEES, AERO_VOLATILE_TAX, AERO_STABLE_FEES, AERO_STABLE_TAX, AERO_SWAP_HOOK);
        h = [
            bytes32(0x6f54720c3eb4326e8cf846308b98ab0c0d070a441ca11ba8cd00be0256af7084),
            0xe9254068c76f9b19f4ab63f7a83b9f82f412362d41609faa232daa65f987bbac,
            0x3ea9d13b9a7ecfa2c5ff590b0b5605cb3571373572cf4e161c0173baaf018759,
            0x7778ded3b75ecadd23f8fc322b1879a57cbbb0d7e3f548c3143eb9542ba4b8a2,
            0x725fdf87a8c681853acfc3b222120d01d603281f1e1d4377c4dac17054c76456,
            0xe2a176e5d2bcfb214b784ec6d6733708a6376a464f203cc265c284c9f349fea3,
            0x7340cf80843bd721bcaefbfc050e38304cb4174c239e6e914e3056f27f39b11c,
            0x0e72100f63ce8e32c95370fa9636d38c8cf434a820f2a7a69985e50930d2cb85,
            0x4961963494e47f363617ab9a0f3999a28b33c519e51392952db06350cce700bd,
            0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0,
            0x95707a4ac71f20181a63ef7d180e3c625be5d20fc8f6f980befa966bad568132,
            0x83b2af6e9f3158defc2811cbcb0db71ecf8b2ba2abea39c39e370ac5c6f43eb6,
            0x628fe0455fa1787ee8dd00677bccf958dd341f0d74039da40b0582080ac92f5e,
            0xccdecaad56ab1bfab03e34ecf082661df958184c89254f7f2d5f31865abb90e0,
            0x15269fbb3aca4305485be2669a8394ec6a14c75181e1eb4c2d46c5b1ee2a7782,
            0x9d1476a920eac769acf23251d79fd656f5566538080c06fc05573e5946b64a91,
            0x94f56a671c80e4670074161c0c5b4d032949d68bfa07191264dc11ed2b18db45,
            0xd22754a0a3b39db7298dbbc2be1e34b34320988ea67065c85fa28ae66c02d31e,
            0x772fb5c610b40a122036f544e5b9b5bce6becb19db9524331289d1aaed2d5888,
            0x916bc5496cc07ea86289bc3a08a90f93dcae34686be6634f6e89ef260c3df4fa,
            0xe63484f408c701770737a3c40e435c8183c66b1663f3a8777ce44dd73aff339b,
            0xcd0b88f96b36edf4d58c6b41119653e25d12bf52d1ea1cd7f636eab29cdb0bd1,
            0xd4a9f98ebd41e4c4e7ae646f1a1f8eaa1205100906f34299a3cd7e4ed567c929,
            0x8826beb783dc6b6c44a392fac83a4a02cceb84bb2ae1e60fc70193565f15c44f,
            0x59de6c7ead685b6295ef7dccb7ee30cd2881c697267d09718790f998db3cf016,
            0xf247ee419fe1dcfedf09c9939822a2276de0c9d2d45fd30330998a448345e803,
            0x59de6c7ead685b6295ef7dccb7ee30cd2881c697267d09718790f998db3cf016,
            0xbc4dcb6544ee340d248fd21ccf8bc9c22261cdc7a011b053cfdca9b77981841f
        ];
    }

    function test_pin_codeHashes() public view {
        (address[28] memory a, bytes32[28] memory h) = _pins();
        for (uint256 i; i < a.length; ++i) {
            assertEq(a[i].codehash, h[i], vm.toString(a[i]));
        }
    }

    function test_pin_implementationsAndRegistries() public view {
        assertEq(IAeroPoolFactory(d.AERO_VOLATILE()).implementation(), AERO_VOLATILE_IMPL);
        assertEq(IAeroPoolFactory(d.AERO_STABLE()).implementation(), AERO_STABLE_IMPL);
        assertEq(ICLFactory(d.AERO_SLIPSTREAM()).poolImplementation(), AERO_CL_IMPL);
        assertEq(IAeroPoolFactory(d.AERODROME_CLASSIC()).implementation(), AERODROME_POOL_IMPL);
        assertEq(ICLFactory(d.AERODROME_SLIPSTREAM()).poolImplementation(), AERODROME_CL_IMPL);
        assertEq(ICLFactory(d.AERODROME_SLIPSTREAM_2()).poolImplementation(), AERODROME_CL_IMPL_2);
        assertEq(ICLFactory(d.AERODROME_SLIPSTREAM_3()).poolImplementation(), AERODROME_CL_IMPL_3);

        // Aero's fees: set by its admins, and outside this repository's reach.
        assertEq(IAeroModules(d.AERO_VOLATILE()).feeModule(), AERO_VOLATILE_FEES);
        assertEq(IAeroModules(d.AERO_VOLATILE()).mevTaxModule(), AERO_VOLATILE_TAX);
        assertEq(IAeroModules(d.AERO_STABLE()).feeModule(), AERO_STABLE_FEES);
        assertEq(IAeroModules(d.AERO_STABLE()).mevTaxModule(), AERO_STABLE_TAX);
        assertEq(ISwapHooks(d.AERO_SLIPSTREAM()).defaultSwapHook(), AERO_SWAP_HOOK);

        // The registries list exactly the factories the swapper fixes.
        address[] memory aero = IAeroRegistry(AERO_REGISTRY).targetFactories();
        assertEq(aero.length, 3);
        (address a0, address a1, address a2) = (aero[0], aero[1], aero[2]);
        assertEq(a0, d.AERO_VOLATILE());
        assertEq(a1, d.AERO_STABLE());
        assertEq(a2, d.AERO_SLIPSTREAM());
        address[] memory aerodrome = IAerodromeRegistry(AERODROME_REGISTRY).poolFactories();
        assertEq(aerodrome.length, 4);
        assertEq(aerodrome[0], d.AERODROME_CLASSIC());
        assertEq(aerodrome[1], d.AERODROME_SLIPSTREAM());
        assertEq(aerodrome[2], d.AERODROME_SLIPSTREAM_2());
        assertEq(aerodrome[3], d.AERODROME_SLIPSTREAM_3());

        // Only Hydrex's pair factory is an upgradeable proxy, behind a one-day timelock.
        address[12] memory e = d.exchanges();
        for (uint256 i; i < e.length; ++i) {
            address impl = address(uint160(uint256(vm.load(e[i], IMPL_SLOT))));
            assertEq(impl, e[i] == d.HYDREX_CLASSIC() ? HYDREX_PAIR_FACTORY_IMPL : address(0));
        }
        assertEq(address(uint160(uint256(vm.load(d.HYDREX_CLASSIC(), ADMIN_SLOT)))), HYDREX_PROXY_ADMIN);
        assertEq(IOwned(HYDREX_PROXY_ADMIN).owner(), HYDREX_TIMELOCK);
        assertEq(ITimelock(HYDREX_TIMELOCK).getMinDelay(), 1 days);
        assertEq(IOwned(d.HYDREX_ALGEBRA()).owner(), ALGEBRA_OWNER);
        assertEq(ALGEBRA_OWNER.code.length, 0);
    }

    function test_pin_poolsAreClonesOfTheImplementations() public view {
        string[4] memory names =
            ["aerodromeClassic", "aerodromeSlipstream", "aerodromeSlipstream2", "aerodromeSlipstream3"];
        address[4] memory impls = [AERODROME_POOL_IMPL, AERODROME_CL_IMPL, AERODROME_CL_IMPL_2, AERODROME_CL_IMPL_3];
        for (uint256 i; i < names.length; ++i) {
            address pool = fx.readAddressArray(string.concat(".routes.", names[i], ".pools"))[0];
            assertEq(pool.code, _clone(impls[i]), names[i]);
        }
    }

    function test_fork_hydrexAlgebra() public {
        _check("hydrexAlgebra");
    }

    function test_fork_hydrexClassic() public {
        _check("hydrexClassic");
    }

    function test_fork_aerodromeClassic() public {
        _check("aerodromeClassic");
    }

    function test_fork_aerodromeSlipstream() public {
        _check("aerodromeSlipstream");
    }

    function test_fork_aerodromeSlipstream2() public {
        _check("aerodromeSlipstream2");
    }

    function test_fork_aerodromeSlipstream3() public {
        _check("aerodromeSlipstream3");
    }

    function test_fork_uniswapV2() public {
        _check("uniswapV2");
    }

    function test_fork_uniswapV3() public {
        _check("uniswapV3");
    }

    function test_fork_uniswapV4() public {
        _check("uniswapV4");
    }

    function test_fork_uniswapV4_cbBtcToEthToUsdc() public {
        _check("uniswapV4Native");
    }

    function test_fork_hydxThroughWeth() public {
        _check("hydxThroughWeth");
    }

    function test_fork_quoteMatchesThePoolsOwnQuotes() public {
        string[11] memory names = [
            "hydrexAlgebra",
            "hydrexClassic",
            "aerodromeClassic",
            "aerodromeSlipstream",
            "aerodromeSlipstream2",
            "aerodromeSlipstream3",
            "uniswapV2",
            "uniswapV3",
            "uniswapV4",
            "uniswapV4Native",
            "hydxThroughWeth"
        ];
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](names.length);
        uint256[] memory expected = new uint256[](names.length);
        for (uint256 i; i < names.length; ++i) {
            (routes[i],, expected[i]) = _route(names[i]);
        }
        ImmutableSwapper.Result[] memory quoted = swapper.quote(routes);
        for (uint256 i; i < names.length; ++i) {
            assertTrue(quoted[i].done, names[i]);
            assertEq(quoted[i].usdcOut, expected[i], names[i]);
        }
    }

    function test_fork_aeroVolatile() public {
        _aeroVolatilePool();
        _checkCreated("aeroVolatile");
    }

    function test_fork_aeroStable() public {
        address pool = IAeroPoolFactory(d.AERO_STABLE()).createPool(EURC, USDC);
        _fund(EURC, pool, 100_000e6);
        _fund(USDC, pool, 100_000e6);
        IClassicMint(pool).mint(address(this));
        _checkCreated("aeroStable");
    }

    function test_fork_aeroSlipstream() public {
        (uint160 price, int24 tick,,,,,) = ISlot0(UNISWAP_V3_WETH_USDC).slot0();
        address pool = ICLFactory(d.AERO_SLIPSTREAM()).createPool(WETH, USDC, 100, price);
        _fund(WETH, address(this), 1000e18);
        _fund(USDC, address(this), 3_000_000e6);
        tick -= tick % 100;
        ICLPool(pool).mint(address(this), tick - 10_000, tick + 10_000, 1e16, "");
        _checkCreated("aeroSlipstream");
    }

    // Aero's MEV tax: above a 1 gwei tip, a swap priced without the caller's fee is refused.
    function test_fork_aeroTax_onlyTheTotalFeePricesASwap() public {
        address pool = _aeroVolatilePool();
        vm.txGasPrice(block.basefee + 2 gwei);
        uint256 plain = IClassicPool(pool).getAmountOut(1e18, WETH);

        uint256 snapshot = vm.snapshotState();
        vm.startPrank(MORPHO);
        IERC20(WETH).transfer(pool, 1e18);
        vm.expectRevert();
        IClassicPool(pool).swap(0, plain, MORPHO, "");
        vm.stopPrank();
        vm.revertToState(snapshot);

        (ImmutableSwapper.Route memory r, address holder,) = _route("aeroVolatile");
        r.amount = 1e18;
        r.hops[0].pool = pool;
        (ImmutableSwapper.Result memory res,) = _swapAs(holder, r);
        assertTrue(res.usdcOut < plain, "the tax applies");
        console.log("Aero volatile, 1 WETH with a 2 gwei tip:", res.usdcOut, "USDC, untaxed:", plain);
    }

    function test_fork_gas_maxRoutesOfMaxHops() public {
        uint256 cheapest = _gasOfMaxRoutes("gasCheapest");
        uint256 dearest = _gasOfMaxRoutes("gasDearest");
        console.log("20 routes of 3 Uniswap v2 hops:", cheapest);
        console.log("20 routes of 3 Hydrex Algebra hops:", dearest);
        assertLt(cheapest, TX_GAS_CAP);
        assertGt(dearest, TX_GAS_CAP, "the limits alone do not keep a call under Base's cap");
    }

    function _gasOfMaxRoutes(string memory name) internal returns (uint256 gasUsed) {
        (ImmutableSwapper.Route memory r, address holder,) = _route(name);
        uint256 n = swapper.MAX_ROUTES();
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](n);
        for (uint256 i; i < n; ++i) {
            routes[i] = r;
        }
        vm.startPrank(holder);
        IApprove(r.token).approve(address(swapper), r.amount * n);
        uint256 before = gasleft();
        (ImmutableSwapper.Result[] memory results,,) = swapper.swap(routes, block.timestamp, false);
        gasUsed = before - gasleft();
        vm.stopPrank();
        for (uint256 i; i < n; ++i) {
            assertTrue(results[i].done);
        }
    }

    function _check(string memory name) internal {
        (ImmutableSwapper.Route memory r, address holder, uint256 expected) = _route(name);
        (ImmutableSwapper.Result memory res, uint256 gasUsed) = _swapAs(holder, r);
        console.log(name, "gas:", gasUsed);
        assertEq(res.usdcOut, expected, "the pools' own quote at the block");
    }

    function _checkCreated(string memory name) internal {
        (ImmutableSwapper.Route memory r, address holder,) = _route(name);
        if (r.hops[0].pool == address(0)) r.hops[0].pool = _poolOf(name);
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](1);
        routes[0] = r;
        vm.prank(holder);
        ImmutableSwapper.Result memory quoted = swapper.quote(routes)[0];
        (ImmutableSwapper.Result memory res, uint256 gasUsed) = _swapAs(holder, r);
        console.log(name, "gas:", gasUsed);
        assertGt(res.usdcOut, 0);
        assertEq(res.usdcOut, quoted.usdcOut, "swap matches quote");
        assertEq(res.amountIn, quoted.amountIn);
    }

    function _poolOf(string memory name) internal view returns (address) {
        if (keccak256(bytes(name)) == keccak256("aeroVolatile")) return _getPool(d.AERO_VOLATILE(), WETH, USDC);
        if (keccak256(bytes(name)) == keccak256("aeroStable")) return _getPool(d.AERO_STABLE(), EURC, USDC);
        (bool ok, bytes memory ret) = d.AERO_SLIPSTREAM()
            .staticcall(abi.encodeWithSignature("getPool(address,address,int24)", WETH, USDC, int24(100)));
        assertTrue(ok);
        return abi.decode(ret, (address));
    }

    function _getPool(address factory, address a, address b) internal view returns (address) {
        (bool ok, bytes memory ret) = factory.staticcall(abi.encodeWithSignature("getPool(address,address)", a, b));
        assertTrue(ok);
        return abi.decode(ret, (address));
    }

    // Swaps one route as holder, and checks the split of the USDC and that the swapper keeps nothing.
    function _swapAs(address holder, ImmutableSwapper.Route memory r)
        internal
        returns (ImmutableSwapper.Result memory res, uint256 gasUsed)
    {
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](1);
        routes[0] = r;
        uint256 holderBefore = IERC20(USDC).balanceOf(holder);
        uint256 treasuryBefore = IERC20(USDC).balanceOf(TREASURY);
        vm.startPrank(holder);
        IApprove(r.token).approve(address(swapper), r.amount);
        gasUsed = gasleft();
        (ImmutableSwapper.Result[] memory results, uint256 paid, uint256 fee) =
            swapper.swap(routes, block.timestamp, false);
        gasUsed -= gasleft();
        vm.stopPrank();
        res = results[0];
        assertEq(res.amountIn, r.amount);
        assertEq(fee, res.usdcOut / 100, "exactly 1%");
        assertEq(paid, res.usdcOut - fee);
        assertEq(IERC20(USDC).balanceOf(holder) - holderBefore, paid);
        assertEq(IERC20(USDC).balanceOf(TREASURY) - treasuryBefore, fee);
        assertEq(IERC20(USDC).balanceOf(address(swapper)), 0);
        assertEq(IERC20(r.token).balanceOf(address(swapper)), 0);
    }

    function _route(string memory name)
        internal
        view
        returns (ImmutableSwapper.Route memory r, address holder, uint256 quote)
    {
        string memory k = string.concat(".routes.", name);
        holder = fx.readAddress(string.concat(k, ".holder"));
        quote = fx.readUint(string.concat(k, ".quote"));
        r.token = fx.readAddress(string.concat(k, ".token"));
        r.amount = fx.readUint(string.concat(k, ".amount"));
        uint256[] memory exchanges = fx.readUintArray(string.concat(k, ".exchanges"));
        address[] memory pools = fx.readAddressArray(string.concat(k, ".pools"));
        address[] memory tokensOut = fx.readAddressArray(string.concat(k, ".tokensOut"));
        uint256[] memory fees = fx.readUintArray(string.concat(k, ".fees"));
        int256[] memory spacings = fx.readIntArray(string.concat(k, ".tickSpacings"));
        r.hops = new ImmutableSwapper.Hop[](exchanges.length);
        for (uint256 i; i < exchanges.length; ++i) {
            r.hops[i] = ImmutableSwapper.Hop(
                ImmutableSwapper.Exchange(exchanges[i]),
                pools[i],
                tokensOut[i],
                // forge-lint: disable-next-line(unsafe-typecast)
                uint24(fees[i]),
                // forge-lint: disable-next-line(unsafe-typecast)
                int24(spacings[i])
            );
        }
    }

    function _aeroVolatilePool() internal returns (address pool) {
        pool = IAeroPoolFactory(d.AERO_VOLATILE()).createPool(WETH, USDC);
        (, address holder, uint256 usdcPerTenthWeth) = _route("uniswapV3");
        assertEq(holder, MORPHO);
        _fund(WETH, pool, 100e18);
        _fund(USDC, pool, usdcPerTenthWeth * 1000);
        IClassicMint(pool).mint(address(this));
    }

    function _fund(address token, address to, uint256 amount) internal {
        vm.prank(MORPHO);
        IERC20(token).transfer(to, amount);
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata) external {
        if (amount0 != 0) IERC20(WETH).transfer(msg.sender, amount0);
        if (amount1 != 0) IERC20(USDC).transfer(msg.sender, amount1);
    }

    // EIP-1167's minimal proxy for impl.
    function _clone(address impl) internal pure returns (bytes memory) {
        return abi.encodePacked(hex"363d3d373d3d3d363d73", impl, hex"5af43d82803e903d91602b57fd5bf3");
    }
}

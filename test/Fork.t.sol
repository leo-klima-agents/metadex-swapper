// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {stdJson} from "forge-std/StdJson.sol";
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {Deploy} from "../script/Deploy.s.sol";
import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";
import {IClassicPool} from "../src/interfaces/IClassicPool.sol";

interface IViews {
    function implementation() external view returns (address);
    function poolImplementation() external view returns (address);
    function feeModule() external view returns (address);
    function mevTaxModule() external view returns (address);
    function defaultSwapHook() external view returns (address);
    function targetFactories() external view returns (address[] memory);
    function poolFactories() external view returns (address[] memory);
    function leafVoter() external view returns (address);
    function ORCHESTRATOR() external view returns (address);
    function adapter() external view returns (address);
    function ROOT_MESSAGE_ORCHESTRATOR() external view returns (address);
    function VOTER() external view returns (address);
    function TOKEN() external view returns (address);
    function owner() external view returns (address);
    function getMinDelay() external view returns (uint256);
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16, uint16, uint16, bool);
}

interface IPoolSetup {
    function createPool(address tokenA, address tokenB) external returns (address);
    function mint(address to) external returns (uint256);
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data)
        external
        returns (uint256, uint256);
}

contract ForkTest is Test {
    using stdJson for string;

    uint256 internal constant TX_GAS_CAP = 2 ** 24;
    bytes32 internal constant IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant TREASURY = 0x450c72de8c0079B49AcedF294a13011bd09D125B;

    address internal constant HYDREX_PAIR_FACTORY_IMPL = 0x421656A4Fc9943a2A7997D6f4f6c04EB2E336d18;
    address internal constant HYDREX_PROXY_ADMIN = 0x6E25D241a3bA9E0278a296b398E9678E5ED8ad40;
    address internal constant HYDREX_TIMELOCK = 0xdF52b5A03E3F5a4178E4F63e8BC51abE691B898F;
    address internal constant HYDREX_STABLE_PAIR = 0xB0EAc8AA498845045229DFE9B68d023f3d019079;
    address internal constant ALGEBRA_OWNER = 0x74266f2b206D1359B83fc74949EF07176FB3AE03;
    address internal constant AERO_REGISTRY = 0x7b2A2c12dC5Ea2a31455952a05031C3E4BB28F3E;
    address internal constant AERODROME_REGISTRY = 0x5C3F18F06CC09CA1910767A34a20F771039E37C0;
    address internal constant AERO_VOLATILE_IMPL = 0x0526cF035C1156b5C598b0d3c2445e38af2e8bDE;
    address internal constant AERO_STABLE_IMPL = 0xf525988f88B7D8b64631D86070FEC5BFDc50C174;
    address internal constant AERO_CL_IMPL = 0x1642634C8CB1C9f1B84c9a1a08534F8c3F4E89f8;
    address internal constant AERODROME_POOL_IMPL = 0xA4e46b4f701c62e14DF11B48dCe76A7d793CD6d7;
    address internal constant AERODROME_CL_IMPL = 0xeC8E5342B19977B4eF8892e02D8DAEcfa1315831;
    address internal constant AERODROME_CL_IMPL_2 = 0x942e97a4c6FdC38B4CD1c0298D37d81fDD8E5A16;
    address internal constant AERODROME_CL_IMPL_3 = 0xc770898522D2A9c8Da7A10D63989b6b58305B665;
    address internal constant AERO_VOLATILE_FEES = 0x7949DE8d67E4F6b8509Bdbb43FF0503aF1247a7A;
    address internal constant AERO_VOLATILE_TAX = 0x830D07BDe136752BCefe0B59a14c2C7af07814AF;
    address internal constant AERO_STABLE_FEES = 0x0195fC76Da986D66B2A468133a1be41E90893Da6;
    address internal constant AERO_STABLE_TAX = 0x78ee48646a7e1507B79443a1d5494095D16AF3B8;
    address internal constant AERO_SWAP_HOOK = 0xC0ed888AfE87ed1AcF01D9f19bB850159e3ce434;

    string internal fx;
    Deploy internal d;
    mapping(address output => ImmutableSwapper) internal swappers;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        vm.skip(bytes(rpc).length == 0);
        fx = vm.readFile("test/fixtures/fork.json");
        vm.createSelectFork(rpc, fx.readUint(".block"));
        assertEq(block.chainid, 8453);
        d = new Deploy();
        address[6] memory deployed = d.run();
        address[6] memory o = d.outputs();
        for (uint256 i; i < o.length; ++i) {
            swappers[o[i]] = ImmutableSwapper(deployed[i]);
        }
    }

    function test_pin_codeHashes() public view {
        assertEq(d.HYDREX_ALGEBRA().codehash, 0x6f54720c3eb4326e8cf846308b98ab0c0d070a441ca11ba8cd00be0256af7084);
        assertEq(d.HYDREX_CLASSIC().codehash, 0xe9254068c76f9b19f4ab63f7a83b9f82f412362d41609faa232daa65f987bbac);
        assertEq(d.AERO_VOLATILE().codehash, 0x975417bdbc8e5df051479a271f5a03582df5f09f179771c68e2708dddeb56ef0);
        assertEq(d.AERO_STABLE().codehash, 0x3b34cd7ed303be01986b097c49f1a29d211783ef63f5e920db0ffb9291396cc2);
        assertEq(d.AERO_SLIPSTREAM().codehash, 0x6c09090837ace0aefe6bfa24a3bc772d13a9775b7e3109c9fece534a0ce053a6);
        assertEq(d.AERODROME_CLASSIC().codehash, 0xe2a176e5d2bcfb214b784ec6d6733708a6376a464f203cc265c284c9f349fea3);
        assertEq(d.AERODROME_SLIPSTREAM().codehash, 0x7340cf80843bd721bcaefbfc050e38304cb4174c239e6e914e3056f27f39b11c);
        assertEq(
            d.AERODROME_SLIPSTREAM_2().codehash, 0x0e72100f63ce8e32c95370fa9636d38c8cf434a820f2a7a69985e50930d2cb85
        );
        assertEq(
            d.AERODROME_SLIPSTREAM_3().codehash, 0x4961963494e47f363617ab9a0f3999a28b33c519e51392952db06350cce700bd
        );
        assertEq(d.UNISWAP_V2().codehash, 0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0);
        assertEq(d.UNISWAP_V3().codehash, 0x95707a4ac71f20181a63ef7d180e3c625be5d20fc8f6f980befa966bad568132);
        assertEq(d.UNISWAP_V4().codehash, 0x83b2af6e9f3158defc2811cbcb0db71ecf8b2ba2abea39c39e370ac5c6f43eb6);
        assertEq(HYDREX_PAIR_FACTORY_IMPL.codehash, 0x628fe0455fa1787ee8dd00677bccf958dd341f0d74039da40b0582080ac92f5e);
        assertEq(HYDREX_PROXY_ADMIN.codehash, 0xccdecaad56ab1bfab03e34ecf082661df958184c89254f7f2d5f31865abb90e0);
        assertEq(AERO_VOLATILE_IMPL.codehash, 0x15269fbb3aca4305485be2669a8394ec6a14c75181e1eb4c2d46c5b1ee2a7782);
        assertEq(AERO_STABLE_IMPL.codehash, 0x9d1476a920eac769acf23251d79fd656f5566538080c06fc05573e5946b64a91);
        assertEq(AERO_CL_IMPL.codehash, 0x041172c7cbffc45627f9dd52727a0124cd6eeb2b5830ab392df54f71a6948693);
        assertEq(AERODROME_POOL_IMPL.codehash, 0xd22754a0a3b39db7298dbbc2be1e34b34320988ea67065c85fa28ae66c02d31e);
        assertEq(AERODROME_CL_IMPL.codehash, 0x772fb5c610b40a122036f544e5b9b5bce6becb19db9524331289d1aaed2d5888);
        assertEq(AERODROME_CL_IMPL_2.codehash, 0x916bc5496cc07ea86289bc3a08a90f93dcae34686be6634f6e89ef260c3df4fa);
        assertEq(AERODROME_CL_IMPL_3.codehash, 0xe63484f408c701770737a3c40e435c8183c66b1663f3a8777ce44dd73aff339b);
        assertEq(AERO_REGISTRY.codehash, 0xcd0b88f96b36edf4d58c6b41119653e25d12bf52d1ea1cd7f636eab29cdb0bd1);
        assertEq(AERODROME_REGISTRY.codehash, 0xd4a9f98ebd41e4c4e7ae646f1a1f8eaa1205100906f34299a3cd7e4ed567c929);
        assertEq(AERO_VOLATILE_FEES.codehash, 0xa56614fe447178e62c473ff1333d660c1dbb70965b4a059fae228bf52457c0f2);
        assertEq(AERO_VOLATILE_TAX.codehash, 0x59de6c7ead685b6295ef7dccb7ee30cd2881c697267d09718790f998db3cf016);
        assertEq(AERO_STABLE_FEES.codehash, 0xe0c19912c35391d5bd218fc0903c3116d9915dc36b4f0b93eb75cf19932c12ac);
        assertEq(AERO_STABLE_TAX.codehash, 0x59de6c7ead685b6295ef7dccb7ee30cd2881c697267d09718790f998db3cf016);
        assertEq(AERO_SWAP_HOOK.codehash, 0x198b45ce022f423a9852526890d236531333e97861078501357e1c72f0eeecbd);
        assertEq(d.AERO().codehash, 0x4a7a844a493b672816a8adadf8500083dd100dd25976803f3964c079a819d0b9);
    }

    function test_pin_implementationsAndRegistries() public view {
        assertEq(IViews(d.AERO_VOLATILE()).implementation(), AERO_VOLATILE_IMPL);
        assertEq(IViews(d.AERO_STABLE()).implementation(), AERO_STABLE_IMPL);
        assertEq(IViews(d.AERO_SLIPSTREAM()).poolImplementation(), AERO_CL_IMPL);
        assertEq(IViews(d.AERODROME_CLASSIC()).implementation(), AERODROME_POOL_IMPL);
        assertEq(IViews(d.AERODROME_SLIPSTREAM()).poolImplementation(), AERODROME_CL_IMPL);
        assertEq(IViews(d.AERODROME_SLIPSTREAM_2()).poolImplementation(), AERODROME_CL_IMPL_2);
        assertEq(IViews(d.AERODROME_SLIPSTREAM_3()).poolImplementation(), AERODROME_CL_IMPL_3);

        assertEq(IViews(d.AERO_VOLATILE()).feeModule(), AERO_VOLATILE_FEES);
        assertEq(IViews(d.AERO_VOLATILE()).mevTaxModule(), AERO_VOLATILE_TAX);
        assertEq(IViews(d.AERO_STABLE()).feeModule(), AERO_STABLE_FEES);
        assertEq(IViews(d.AERO_STABLE()).mevTaxModule(), AERO_STABLE_TAX);
        assertEq(IViews(d.AERO_SLIPSTREAM()).defaultSwapHook(), AERO_SWAP_HOOK);

        address leafVoter = IViews(AERO_REGISTRY).leafVoter();
        address orchestrator = IViews(leafVoter).ORCHESTRATOR();
        address adapter = IViews(orchestrator).adapter();
        address rootVoter = IViews(IViews(adapter).ROOT_MESSAGE_ORCHESTRATOR()).VOTER();
        assertEq(IViews(rootVoter).TOKEN(), d.AERO());

        address[] memory aero = IViews(AERO_REGISTRY).targetFactories();
        assertEq(aero.length, 3);
        assertEq(aero[0], d.AERO_VOLATILE());
        assertEq(aero[1], d.AERO_STABLE());
        assertEq(aero[2], d.AERO_SLIPSTREAM());
        address[] memory aerodrome = IViews(AERODROME_REGISTRY).poolFactories();
        assertEq(aerodrome.length, 4);
        assertEq(aerodrome[0], d.AERODROME_CLASSIC());
        assertEq(aerodrome[1], d.AERODROME_SLIPSTREAM());
        assertEq(aerodrome[2], d.AERODROME_SLIPSTREAM_2());
        assertEq(aerodrome[3], d.AERODROME_SLIPSTREAM_3());

        address[12] memory e = d.exchanges();
        for (uint256 i; i < e.length; ++i) {
            address impl = address(uint160(uint256(vm.load(e[i], IMPL_SLOT))));
            assertEq(impl, e[i] == d.HYDREX_CLASSIC() ? HYDREX_PAIR_FACTORY_IMPL : address(0));
        }
        assertEq(address(uint160(uint256(vm.load(d.HYDREX_CLASSIC(), ADMIN_SLOT)))), HYDREX_PROXY_ADMIN);
        assertEq(IViews(HYDREX_PROXY_ADMIN).owner(), HYDREX_TIMELOCK);
        assertEq(IViews(HYDREX_TIMELOCK).getMinDelay(), 1 days);
        assertEq(IViews(d.HYDREX_ALGEBRA()).owner(), ALGEBRA_OWNER);
        assertEq(ALGEBRA_OWNER.code.length, 0);
    }

    function test_pin_poolsAreClonesOfTheImplementations() public view {
        string[6] memory names = [
            "aeroVolatile",
            "aeroSlipstream",
            "aerodromeClassic",
            "aerodromeSlipstream",
            "aerodromeSlipstream2",
            "aerodromeSlipstream3"
        ];
        address[6] memory impls = [
            AERO_VOLATILE_IMPL,
            AERO_CL_IMPL,
            AERODROME_POOL_IMPL,
            AERODROME_CL_IMPL,
            AERODROME_CL_IMPL_2,
            AERODROME_CL_IMPL_3
        ];
        for (uint256 i; i < names.length; ++i) {
            assertEq(_pool(names[i]).code, _clone(impls[i]), names[i]);
        }
    }

    function test_hydrexAlgebra() public {
        _check("hydrexAlgebra", address(0));
    }

    function test_hydrexClassic() public {
        _check("hydrexClassic", address(0));
    }

    function test_aerodromeClassic() public {
        _check("aerodromeClassic", address(0));
    }

    function test_aerodromeSlipstream() public {
        _check("aerodromeSlipstream", address(0));
    }

    function test_aerodromeSlipstream2() public {
        _check("aerodromeSlipstream2", address(0));
    }

    function test_aerodromeSlipstream3() public {
        _check("aerodromeSlipstream3", address(0));
    }

    function test_uniswapV2() public {
        _check("uniswapV2", address(0));
    }

    function test_uniswapV3() public {
        _check("uniswapV3", address(0));
    }

    function test_uniswapV4() public {
        _check("uniswapV4", address(0));
    }

    function test_uniswapV4Native() public {
        _check("uniswapV4Native", address(0));
    }

    function test_hydxThroughWeth() public {
        _check("hydxThroughWeth", address(0));
    }

    function test_usdcToEurc() public {
        _check("usdcToEurc", address(0));
    }

    function test_wethToEurc() public {
        _check("wethToEurc", address(0));
    }

    function test_usdcToWeth() public {
        _check("usdcToWeth", address(0));
    }

    function test_cbBtcToWeth() public {
        _check("cbBtcToWeth", address(0));
    }

    function test_wethToCbBtc() public {
        _check("wethToCbBtc", address(0));
    }

    function test_usdcToCbBtc() public {
        _check("usdcToCbBtc", address(0));
    }

    function test_wethToHydx() public {
        _check("wethToHydx", address(0));
    }

    function test_usdcToHydx() public {
        _check("usdcToHydx", address(0));
    }

    function test_hydrexStablePair_asksOneWeiLess() public {
        address pair = HYDREX_STABLE_PAIR;
        address[2] memory tokens = [IClassicPool(pair).token0(), IClassicPool(pair).token1()];
        uint256[2] memory amounts = [uint256(55_253_882_642_157_773), 128_170_400_719_120_340];
        address holder = makeAddr("holder");
        for (uint256 i; i < 2; ++i) {
            (address tokenIn, address tokenOut) = (tokens[i], tokens[1 - i]);
            uint256 quoted = IClassicPool(pair).getAmountOut(amounts[i], tokenIn);
            uint256 snap = vm.snapshotState();
            deal(tokenIn, pair, IERC20(tokenIn).balanceOf(pair) + amounts[i]);
            (uint256 out0, uint256 out1) = i == 0 ? (uint256(0), quoted) : (quoted, uint256(0));
            vm.expectRevert(bytes("K"));
            IClassicPool(pair).swap(out0, out1, address(this), "");
            vm.revertToState(snap);

            swappers[tokenOut] = new ImmutableSwapper(tokenOut, d.exchanges());
            ImmutableSwapper.Route memory r;
            (r.token, r.amount) = (tokenIn, amounts[i]);
            r.hops = new ImmutableSwapper.Hop[](1);
            r.hops[0] = ImmutableSwapper.Hop(ImmutableSwapper.Exchange.HydrexClassic, pair, tokenOut, 0, 0);
            deal(tokenIn, holder, amounts[i]);
            (ImmutableSwapper.Result memory res,) = _swapAs(holder, r);
            assertEq(res.amountOut, quoted - 1);
            vm.revertToState(snap);
        }
    }

    function test_wethToAero() public {
        address pool = _pool("wethToAero");
        deal(WETH, pool, 100e18);
        deal(d.AERO(), pool, 296_000e18);
        IPoolSetup(pool).mint(address(this));
        _check("wethToAero", pool);
    }

    function test_aeroVolatile() public {
        _check("aeroVolatile", _aeroVolatilePool());
    }

    function test_aeroStable() public {
        address pool = IPoolSetup(d.AERO_STABLE()).createPool(EURC, USDC);
        deal(EURC, pool, 100_000e6);
        deal(USDC, pool, 100_000e6);
        IPoolSetup(pool).mint(address(this));
        _check("aeroStable", pool);
    }

    function test_aeroSlipstream() public {
        address pool = _pool("aeroSlipstream");
        (, int24 tick,,,,) = IViews(pool).slot0();
        deal(WETH, address(this), 1000e18);
        deal(USDC, address(this), 3_000_000e6);
        tick -= tick % 100;
        IPoolSetup(pool).mint(address(this), tick - 10_000, tick + 10_000, 1e16, "");
        _check("aeroSlipstream", pool);
    }

    function test_aeroTax_onlyTheTotalFeePricesASwap() public {
        address pool = _aeroVolatilePool();
        vm.txGasPrice(block.basefee + 2 gwei);
        uint256 plain = IClassicPool(pool).getAmountOut(1e18, WETH);

        uint256 snap = vm.snapshotState();
        deal(WETH, pool, IERC20(WETH).balanceOf(pool) + 1e18);
        vm.expectRevert(bytes4(keccak256("K()")));
        IClassicPool(pool).swap(0, plain, address(this), "");
        vm.revertToState(snap);

        (ImmutableSwapper.Route memory r, address holder,) = _fixture("aeroVolatile");
        r.amount = 1e18;
        r.hops[0].pool = pool;
        (ImmutableSwapper.Result memory res,) = _swapAs(holder, r);
        assertLt(res.amountOut, plain, "the tax applies");
        console.log("Aero volatile, 1 WETH with a 2 gwei tip:", res.amountOut, "USDC, untaxed:", plain);
    }

    function test_gas_batchesFitUnderTheCap() public {
        uint256 cheapest = _gasOfRoutes("gasCheapest", 20);
        uint256 dearest = _gasOfRoutes("gasDearest", 4);
        console.log("20 routes of 3 Uniswap v2 hops:", cheapest);
        console.log("4 routes of 3 Hydrex Algebra hops:", dearest);
        assertLt(cheapest, TX_GAS_CAP);
        assertLt(dearest, TX_GAS_CAP);
    }

    function _gasOfRoutes(string memory name, uint256 n) internal returns (uint256 gasUsed) {
        (ImmutableSwapper.Route memory r, address holder,) = _fixture(name);
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](n);
        for (uint256 i; i < n; ++i) {
            routes[i] = r;
        }
        ImmutableSwapper swapper = _swapperFor(r);
        vm.startPrank(holder);
        IERC20(r.token).approve(address(swapper), r.amount * n);
        uint256 before = gasleft();
        (ImmutableSwapper.Result[] memory results,,) = swapper.swap(routes, vm.getBlockTimestamp(), false);
        gasUsed = before - gasleft();
        vm.stopPrank();
        for (uint256 i; i < n; ++i) {
            assertTrue(results[i].done);
        }
    }

    function _check(string memory name, address pool) internal {
        (ImmutableSwapper.Route memory r, address holder, uint256 expected) = _fixture(name);
        if (pool != address(0)) r.hops[0].pool = pool;
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](1);
        routes[0] = r;
        vm.prank(holder);
        ImmutableSwapper.Result memory quoted = _swapperFor(r).quote(routes)[0];
        (ImmutableSwapper.Result memory res, uint256 gasUsed) = _swapAs(holder, r);
        console.log(name, "gas:", gasUsed);
        assertEq(abi.encode(quoted), abi.encode(res), "quote matches swap");
        assertGt(res.amountOut, 0);
        if (pool == address(0)) assertEq(res.amountOut, expected, "the pools' own quote at the block");
    }

    function _swapperFor(ImmutableSwapper.Route memory r) internal view returns (ImmutableSwapper) {
        return swappers[r.hops[r.hops.length - 1].tokenOut];
    }

    function _swapAs(address holder, ImmutableSwapper.Route memory r)
        internal
        returns (ImmutableSwapper.Result memory res, uint256 gasUsed)
    {
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](1);
        routes[0] = r;
        ImmutableSwapper swapper = _swapperFor(r);
        IERC20 output = IERC20(swapper.outputToken());
        uint256 holderBefore = output.balanceOf(holder);
        uint256 treasuryBefore = output.balanceOf(TREASURY);
        vm.startPrank(holder);
        IERC20(r.token).approve(address(swapper), r.amount);
        gasUsed = gasleft();
        (ImmutableSwapper.Result[] memory results, uint256 paid, uint256 fee) =
            swapper.swap(routes, vm.getBlockTimestamp(), false);
        gasUsed -= gasleft();
        vm.stopPrank();
        res = results[0];
        assertEq(res.amountIn, r.amount);
        assertEq(fee, res.amountOut / 100, "exactly 1%");
        assertEq(paid, res.amountOut - fee);
        assertEq(output.balanceOf(holder) - holderBefore, paid);
        assertEq(output.balanceOf(TREASURY) - treasuryBefore, fee);
        assertEq(output.balanceOf(address(swapper)), 0);
        assertEq(IERC20(r.token).balanceOf(address(swapper)), 0);
    }

    function _fixture(string memory name)
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
                ImmutableSwapper.Exchange(exchanges[i]), pools[i], tokensOut[i], uint24(fees[i]), int24(spacings[i])
            );
        }
    }

    function _pool(string memory name) internal view returns (address) {
        return fx.readAddressArray(string.concat(".routes.", name, ".pools"))[0];
    }

    function _aeroVolatilePool() internal returns (address pool) {
        pool = _pool("aeroVolatile");
        (,, uint256 usdcPerTenthWeth) = _fixture("uniswapV3");
        deal(WETH, pool, 100e18);
        deal(USDC, pool, usdcPerTenthWeth * 1000);
        IPoolSetup(pool).mint(address(this));
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata) external {
        if (amount0 != 0) IERC20(WETH).transfer(msg.sender, amount0);
        if (amount1 != 0) IERC20(USDC).transfer(msg.sender, amount1);
    }

    function _clone(address impl) internal pure returns (bytes memory) {
        return abi.encodePacked(hex"363d3d373d3d3d363d73", impl, hex"5af43d82803e903d91602b57fd5bf3");
    }
}

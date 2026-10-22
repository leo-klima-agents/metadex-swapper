// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {ImmutableSwapper} from "../../src/ImmutableSwapper.sol";
import {IClassicPool} from "../../src/interfaces/IClassicPool.sol";
import {ForkTest} from "../utils/ForkTest.sol";

interface IBaseViews {
    function implementation() external view returns (address);
    function feeModule() external view returns (address);
    function mevTaxModule() external view returns (address);
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

interface ICLPoolSetup {
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data)
        external
        returns (uint256, uint256);
}

contract BaseForkTest is ForkTest {
    using stdJson for string;

    uint256 internal constant TX_GAS_CAP = 2 ** 24;
    bytes32 internal constant IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant AERO = 0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee;

    address internal constant AERO_VOLATILE = 0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2;
    address internal constant AERO_STABLE = 0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D;
    address internal constant AERO_SLIPSTREAM = 0x9CB220581b91b0C83223012FE69688b92aD07a76;
    address internal constant HYDREX_CLASSIC = 0xC47F17c4fd96F50eFD2A2448ceDe5C185c084bf0;
    address internal constant HYDREX_ALGEBRA = 0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E;

    address internal constant AERO_REGISTRY = 0x7b2A2c12dC5Ea2a31455952a05031C3E4BB28F3E;
    address internal constant AERO_VOLATILE_IMPL = 0x0526cF035C1156b5C598b0d3c2445e38af2e8bDE;
    address internal constant AERO_STABLE_IMPL = 0xf525988f88B7D8b64631D86070FEC5BFDc50C174;
    address internal constant AERO_CL_IMPL = 0x1642634C8CB1C9f1B84c9a1a08534F8c3F4E89f8;
    address internal constant AERO_VOLATILE_FEES = 0x7949DE8d67E4F6b8509Bdbb43FF0503aF1247a7A;
    address internal constant AERO_VOLATILE_TAX = 0x830D07BDe136752BCefe0B59a14c2C7af07814AF;
    address internal constant AERO_STABLE_FEES = 0x0195fC76Da986D66B2A468133a1be41E90893Da6;
    address internal constant AERO_STABLE_TAX = 0x78ee48646a7e1507B79443a1d5494095D16AF3B8;
    address internal constant AERO_SWAP_HOOK = 0xC0ed888AfE87ed1AcF01D9f19bB850159e3ce434;
    address internal constant HYDREX_PAIR_FACTORY_IMPL = 0x421656A4Fc9943a2A7997D6f4f6c04EB2E336d18;
    address internal constant HYDREX_PROXY_ADMIN = 0x6E25D241a3bA9E0278a296b398E9678E5ED8ad40;
    address internal constant HYDREX_TIMELOCK = 0xdF52b5A03E3F5a4178E4F63e8BC51abE691B898F;
    address internal constant HYDREX_STABLE_PAIR = 0xB0EAc8AA498845045229DFE9B68d023f3d019079;
    address internal constant ALGEBRA_OWNER = 0x74266f2b206D1359B83fc74949EF07176FB3AE03;

    function _chainId() internal pure override returns (uint256) {
        return 8453;
    }

    function _name() internal pure override returns (string memory) {
        return "base";
    }

    function _rpcVar() internal pure override returns (string memory) {
        return "BASE_RPC_URL";
    }

    function _pins() internal pure override returns (Pin[] memory p) {
        p = new Pin[](20);
        p[0] = Pin(AERO_VOLATILE, 0x975417bdbc8e5df051479a271f5a03582df5f09f179771c68e2708dddeb56ef0);
        p[1] = Pin(AERO_STABLE, 0x3b34cd7ed303be01986b097c49f1a29d211783ef63f5e920db0ffb9291396cc2);
        p[2] = Pin(AERO_SLIPSTREAM, 0x6c09090837ace0aefe6bfa24a3bc772d13a9775b7e3109c9fece534a0ce053a6);
        p[3] = Pin(
            0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6,
            0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0
        );
        p[4] = Pin(
            0x33128a8fC17869897dcE68Ed026d694621f6FDfD,
            0x95707a4ac71f20181a63ef7d180e3c625be5d20fc8f6f980befa966bad568132
        );
        p[5] = Pin(
            0x498581fF718922c3f8e6A244956aF099B2652b2b,
            0x83b2af6e9f3158defc2811cbcb0db71ecf8b2ba2abea39c39e370ac5c6f43eb6
        );
        p[6] = Pin(HYDREX_CLASSIC, 0xe9254068c76f9b19f4ab63f7a83b9f82f412362d41609faa232daa65f987bbac);
        p[7] = Pin(HYDREX_ALGEBRA, 0x6f54720c3eb4326e8cf846308b98ab0c0d070a441ca11ba8cd00be0256af7084);
        p[8] = Pin(AERO_VOLATILE_IMPL, 0x15269fbb3aca4305485be2669a8394ec6a14c75181e1eb4c2d46c5b1ee2a7782);
        p[9] = Pin(AERO_STABLE_IMPL, 0x9d1476a920eac769acf23251d79fd656f5566538080c06fc05573e5946b64a91);
        p[10] = Pin(AERO_CL_IMPL, 0x041172c7cbffc45627f9dd52727a0124cd6eeb2b5830ab392df54f71a6948693);
        p[11] = Pin(AERO_SWAP_HOOK, 0x198b45ce022f423a9852526890d236531333e97861078501357e1c72f0eeecbd);
        p[12] = Pin(AERO_REGISTRY, 0xcd0b88f96b36edf4d58c6b41119653e25d12bf52d1ea1cd7f636eab29cdb0bd1);
        p[13] = Pin(AERO_VOLATILE_FEES, 0xa56614fe447178e62c473ff1333d660c1dbb70965b4a059fae228bf52457c0f2);
        p[14] = Pin(AERO_VOLATILE_TAX, 0x59de6c7ead685b6295ef7dccb7ee30cd2881c697267d09718790f998db3cf016);
        p[15] = Pin(AERO_STABLE_FEES, 0xe0c19912c35391d5bd218fc0903c3116d9915dc36b4f0b93eb75cf19932c12ac);
        p[16] = Pin(AERO_STABLE_TAX, 0x59de6c7ead685b6295ef7dccb7ee30cd2881c697267d09718790f998db3cf016);
        p[17] = Pin(AERO, 0x4a7a844a493b672816a8adadf8500083dd100dd25976803f3964c079a819d0b9);
        p[18] = Pin(HYDREX_PAIR_FACTORY_IMPL, 0x628fe0455fa1787ee8dd00677bccf958dd341f0d74039da40b0582080ac92f5e);
        p[19] = Pin(HYDREX_PROXY_ADMIN, 0xccdecaad56ab1bfab03e34ecf082661df958184c89254f7f2d5f31865abb90e0);
    }

    function test_pin_aeroModulesAndToken() public view {
        assertEq(IBaseViews(AERO_VOLATILE).implementation(), AERO_VOLATILE_IMPL);
        assertEq(IBaseViews(AERO_STABLE).implementation(), AERO_STABLE_IMPL);
        assertEq(IBaseViews(AERO_VOLATILE).feeModule(), AERO_VOLATILE_FEES);
        assertEq(IBaseViews(AERO_VOLATILE).mevTaxModule(), AERO_VOLATILE_TAX);
        assertEq(IBaseViews(AERO_STABLE).feeModule(), AERO_STABLE_FEES);
        assertEq(IBaseViews(AERO_STABLE).mevTaxModule(), AERO_STABLE_TAX);

        address leafVoter = IBaseViews(AERO_REGISTRY).leafVoter();
        address orchestrator = IBaseViews(leafVoter).ORCHESTRATOR();
        address adapter = IBaseViews(orchestrator).adapter();
        address rootVoter = IBaseViews(IBaseViews(adapter).ROOT_MESSAGE_ORCHESTRATOR()).VOTER();
        assertEq(IBaseViews(rootVoter).TOKEN(), AERO);
    }

    function test_pin_hydrex() public view {
        ImmutableSwapper.Exchange[] memory e = d.config(_chainId()).exchanges;
        for (uint256 i; i < e.length; ++i) {
            address impl = address(uint160(uint256(vm.load(e[i].factory, IMPL_SLOT))));
            assertEq(impl, e[i].factory == HYDREX_CLASSIC ? HYDREX_PAIR_FACTORY_IMPL : address(0));
        }
        assertEq(address(uint160(uint256(vm.load(HYDREX_CLASSIC, ADMIN_SLOT)))), HYDREX_PROXY_ADMIN);
        assertEq(IBaseViews(HYDREX_PROXY_ADMIN).owner(), HYDREX_TIMELOCK);
        assertEq(IBaseViews(HYDREX_TIMELOCK).getMinDelay(), 1 days);
        assertEq(IBaseViews(HYDREX_ALGEBRA).owner(), ALGEBRA_OWNER);
        assertEq(ALGEBRA_OWNER.code.length, 0);
    }

    function test_aeroVolatile() public {
        _check("aeroVolatile");
    }

    function test_aeroStable() public {
        _check("aeroStable");
    }

    function test_aeroSlipstream() public {
        address pool = _pool("aeroSlipstream");
        (, int24 tick,,,,) = IBaseViews(pool).slot0();
        deal(WETH, address(this), 1000e18);
        deal(USDC, address(this), 3_000_000e6);
        tick -= tick % 100;
        ICLPoolSetup(pool).mint(address(this), tick - 10_000, tick + 10_000, 1e16, "");
        _check("aeroSlipstream", pool);
    }

    function test_uniswapV2() public {
        _check("uniswapV2");
    }

    function test_uniswapV3() public {
        _check("uniswapV3");
    }

    function test_uniswapV4() public {
        _check("uniswapV4");
    }

    function test_uniswapV4Native() public {
        _check("uniswapV4Native");
    }

    function test_hydrexClassic() public {
        _check("hydrexClassic");
    }

    function test_hydrexAlgebra() public {
        _check("hydrexAlgebra");
    }

    function test_hydxThroughWeth() public {
        _check("hydxThroughWeth");
    }

    function test_usdcToWeth() public {
        _check("usdcToWeth");
    }

    function test_cbBtcToWeth() public {
        _check("cbBtcToWeth");
    }

    function test_wethToEurc() public {
        _check("wethToEurc");
    }

    function test_usdcToEurc() public {
        _check("usdcToEurc");
    }

    function test_wethToCbBtc() public {
        _check("wethToCbBtc");
    }

    function test_usdcToCbBtc() public {
        _check("usdcToCbBtc");
    }

    function test_wethToAero() public {
        _check("wethToAero");
    }

    function test_wethToHydx() public {
        _check("wethToHydx");
    }

    function test_usdcToHydx() public {
        _check("usdcToHydx");
    }

    function test_aeroTax_onlyTheTotalFeePricesASwap() public {
        (ImmutableSwapper.Route memory r, address holder,) = _fixture("aeroVolatile");
        address pool = _seed("aeroVolatile", r);
        vm.txGasPrice(block.basefee + 2 gwei);
        uint256 plain = IClassicPool(pool).getAmountOut(1e18, WETH);

        uint256 snap = vm.snapshotState();
        deal(WETH, pool, IERC20(WETH).balanceOf(pool) + 1e18);
        vm.expectRevert(bytes4(keccak256("K()")));
        IClassicPool(pool).swap(0, plain, address(this), "");
        vm.revertToState(snap);

        r.amount = 1e18;
        r.hops[0].pool = pool;
        (ImmutableSwapper.Result memory res,) = _swapAs(holder, r);
        assertLt(res.amountOut, plain, "the tax applies");
        console.log("Aero volatile, 1 WETH with a 2 gwei tip:", res.amountOut, "USDC, untaxed:", plain);
    }

    function test_hydrexStablePair_asksOneWeiLess() public {
        address pair = HYDREX_STABLE_PAIR;
        address[2] memory tokens = [IClassicPool(pair).token0(), IClassicPool(pair).token1()];
        uint256[2] memory amounts = [uint256(55_253_882_642_157_773), 128_170_400_719_120_340];
        address holder = makeAddr("holder");
        ImmutableSwapper.Exchange[] memory e = d.config(_chainId()).exchanges;
        for (uint256 i; i < 2; ++i) {
            (address tokenIn, address tokenOut) = (tokens[i], tokens[1 - i]);
            uint256 quoted = IClassicPool(pair).getAmountOut(amounts[i], tokenIn);
            uint256 snap = vm.snapshotState();
            deal(tokenIn, pair, IERC20(tokenIn).balanceOf(pair) + amounts[i]);
            (uint256 out0, uint256 out1) = i == 0 ? (uint256(0), quoted) : (quoted, uint256(0));
            vm.expectRevert(bytes("K"));
            IClassicPool(pair).swap(out0, out1, address(this), "");
            vm.revertToState(snap);

            swappers[tokenOut] = new ImmutableSwapper(tokenOut, e);
            ImmutableSwapper.Route memory r;
            (r.token, r.amount) = (tokenIn, amounts[i]);
            r.hops = new ImmutableSwapper.Hop[](1);
            r.hops[0] = ImmutableSwapper.Hop(_indexOf(HYDREX_CLASSIC), pair, tokenOut, 0, 0);
            deal(tokenIn, holder, amounts[i]);
            (ImmutableSwapper.Result memory res,) = _swapAs(holder, r);
            assertEq(res.amountOut, quoted - 1);
            vm.revertToState(snap);
        }
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

    function _pool(string memory name) internal view returns (address) {
        return fx.readAddressArray(string.concat(".routes.", name, ".pools"))[0];
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata) external {
        if (amount0 != 0) IERC20(WETH).transfer(msg.sender, amount0);
        if (amount1 != 0) IERC20(USDC).transfer(msg.sender, amount1);
    }
}

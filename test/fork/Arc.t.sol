// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {ImmutableSwapper} from "../../src/ImmutableSwapper.sol";
import {ArcNativeCoin} from "../mocks/ArcNativeCoin.sol";
import {ForkTest} from "../utils/ForkTest.sol";

contract ArcForkTest is ForkTest {
    address internal constant USDC = 0x3600000000000000000000000000000000000000;

    function _chainId() internal pure override returns (uint256) {
        return 5042;
    }

    function _name() internal pure override returns (string memory) {
        return "arc";
    }

    function _rpcVar() internal pure override returns (string memory) {
        return "ARC_RPC_URL";
    }

    function _pins() internal pure override returns (Pin[] memory p) {
        p = new Pin[](11);
        // Aero volatile factory
        p[0] = Pin(
            0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2,
            0x9c0e0261ae27222603b3243d66a305513a832d8044b86dc27c49c5e1f491ec0a
        );
        // Aero stable factory
        p[1] = Pin(
            0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D,
            0xfbd6234a243d9f7cf7965a13dc757b060a3870ea0d5bfe3ca7d32152e3e0aa21
        );
        // Aero CLFactory
        p[2] = Pin(
            0x7F83235643181E440433400a027618Cd50879751,
            0xa1e59904fa067e5c6dd0fb484a46a61a49eb583dac80777bb51c9544d551af77
        );
        // UniswapV2Factory
        p[3] = Pin(
            0x89e5DB8B5aA49aA85AC63f691524311AEB649eba,
            0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0
        );
        // UniswapV3Factory
        p[4] = Pin(
            0xf0db7b58379503491d857dB50AC9ece64c653918,
            0x621c4819f7b62d7ddb153206bc30950bcc3f5cc9d24c45661f8c2f31dcbd166d
        );
        // PoolManager
        p[5] = Pin(
            0x8366a39CC670B4001A1121B8F6A443A643e40951,
            0xbd3881180b547f5fe817545743cfb4343e96b1bc6640dcd70c106b0066e95626
        );
        // Aero volatile pool implementation
        p[6] = Pin(
            0x0526cF035C1156b5C598b0d3c2445e38af2e8bDE,
            0x15269fbb3aca4305485be2669a8394ec6a14c75181e1eb4c2d46c5b1ee2a7782
        );
        // Aero stable pool implementation
        p[7] = Pin(
            0xf525988f88B7D8b64631D86070FEC5BFDc50C174,
            0x9d1476a920eac769acf23251d79fd656f5566538080c06fc05573e5946b64a91
        );
        // Aero CLPool implementation
        p[8] = Pin(
            0x1642634C8CB1C9f1B84c9a1a08534F8c3F4E89f8,
            0x041172c7cbffc45627f9dd52727a0124cd6eeb2b5830ab392df54f71a6948693
        );
        // Aero default swap hook
        p[9] = Pin(
            0xC0ed888AfE87ed1AcF01D9f19bB850159e3ce434,
            0x056d298da414cbec176a47008aa320ee36ca3ff40668fcf1cda093d2597fa065
        );
        // Aero FactoryRegistry
        p[10] = Pin(
            0xCe44907DC45D3BFa3f5f6035B0e6E8B22D780A42,
            0x7b99eb4042fd62042cdb3e57683ff9beb485195a23177bf504dd213ddcbf2c07
        );
    }

    // Aero's registry on Arc also lists Aero Lite's three factories, which these deployments leave out.
    function _leftOut() internal pure override returns (address[] memory list) {
        list = new address[](3);
        list[0] = 0x9bc8b3F60D349d687Fb44A018967025E3741F9a5;
        list[1] = 0xaEd253F1aD84d99f2165256D701b2b481DD4CC16;
        list[2] = 0xb89Df768aF2CFE637ceB352c587Fe8edAf491d03;
    }

    function _beforeDeploy() internal override {
        bytes memory code = type(ArcNativeCoin).runtimeCode;
        address[2] memory precompiles =
            [0x1800000000000000000000000000000000000000, 0x1800000000000000000000000000000000000001];
        for (uint256 i; i < precompiles.length; ++i) {
            vm.etch(precompiles[i], code);
            vm.allowCheatcodes(precompiles[i]);
        }
    }

    // The stand-in moves balances with vm.deal, which a reverted call doesn't undo. A quote reverts each swap it
    // prices, so its moves are undone here instead.
    function _quote(address holder, ImmutableSwapper.Route[] memory routes)
        internal
        override
        returns (ImmutableSwapper.Result memory quoted)
    {
        uint256 snap = vm.snapshotState();
        quoted = super._quote(holder, routes);
        vm.revertToState(snap);
    }

    // USDC on Arc is the native currency: its balance is the native balance, in 6 decimals instead of 18.
    function _fund(address token, address to, uint256 amount) internal override {
        if (token == USDC) vm.deal(to, to.balance + amount * 1e12);
        else super._fund(token, to, amount);
    }

    function test_aeroVolatile() public {
        _check("aeroVolatile");
    }

    function test_aeroStable() public {
        _check("aeroStable");
    }

    function test_aeroSlipstream() public {
        _check("aeroSlipstream");
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

    function test_usdcToEurc() public {
        _check("usdcToEurc");
    }

    function test_usdcToCirBtc() public {
        _check("usdcToCirBtc");
    }
}

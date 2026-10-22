// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {ForkTest} from "../utils/ForkTest.sol";

contract EthereumForkTest is ForkTest {
    function _chainId() internal pure override returns (uint256) {
        return 1;
    }

    function _name() internal pure override returns (string memory) {
        return "ethereum";
    }

    function _rpcVar() internal pure override returns (string memory) {
        return "ETHEREUM_RPC_URL";
    }

    function _pins() internal pure override returns (Pin[] memory p) {
        p = new Pin[](11);
        // Aero volatile factory
        p[0] = Pin(
            0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2,
            0x45c305d6825d576c93eeaf61da718391f70f80e3677caef2ebb26fbc94d0923c
        );
        // Aero stable factory
        p[1] = Pin(
            0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D,
            0x128a5d36260b010f7cb09a83f01b4910a57fe680e273d4eb7fab81c05ed9ee1f
        );
        // Aero CLFactory
        p[2] = Pin(
            0xF4Fd2E6c5B60c5b365cd1B96DD6245E6D60414c2,
            0x3e53af145d8106d91fad73c6dbbbfe3229c5aa96aab1e18a4bf49a705c773ef5
        );
        // UniswapV2Factory
        p[3] = Pin(
            0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f,
            0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0
        );
        // UniswapV3Factory
        p[4] = Pin(
            0x1F98431c8aD98523631AE4a59f267346ea31F984,
            0x4d7b8525cd5d14343fa67a732fba5b24cddba11620ca88392f4ec6c52f91fd69
        );
        // PoolManager
        p[5] = Pin(
            0x000000000004444c5dc75cB358380D2e3dE08A90,
            0x785f1014552b7ce7d5fb7d0c970ca60edee94fd00425d7ca21609acac7ce1293
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
            0xd64b9e760431c312c53515167ffb260b357705388da9354f31095d974e19e449
        );
        // Aero FactoryRegistry
        p[10] = Pin(
            0xdd1705e23762F4D6e44D8C31BD8Ea80c54612239,
            0xcd0b88f96b36edf4d58c6b41119653e25d12bf52d1ea1cd7f636eab29cdb0bd1
        );
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

    function test_uniswapV4Native() public {
        _check("uniswapV4Native");
    }

    function test_usdcToEurc() public {
        _check("usdcToEurc");
    }

    function test_usdcToWeth() public {
        _check("usdcToWeth");
    }

    function test_wethToCbBtc() public {
        _check("wethToCbBtc");
    }
}

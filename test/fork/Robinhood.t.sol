// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {ForkTest} from "../utils/ForkTest.sol";

contract RobinhoodForkTest is ForkTest {
    function _chainId() internal pure override returns (uint256) {
        return 4663;
    }

    function _name() internal pure override returns (string memory) {
        return "robinhood";
    }

    function _rpcVar() internal pure override returns (string memory) {
        return "ROBINHOOD_RPC_URL";
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
            0xc63d7338c178e805c544B8f897066bD3BBcBE136,
            0x3e53af145d8106d91fad73c6dbbbfe3229c5aa96aab1e18a4bf49a705c773ef5
        );
        // UniswapV2Factory
        p[3] = Pin(
            0x8bcEaA40B9AcdfAedF85AdF4FF01F5Ad6517937f,
            0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0
        );
        // UniswapV3Factory
        p[4] = Pin(
            0x1f7d7550B1b028f7571E69A784071F0205FD2EfA,
            0xec72b1abd1f2faee020cfea9c646bd8994f9fb389054f6e574f103a895091739
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
            0xcbeeeb0c4af5dec3426c4d6484190547ea03e88da5df3a78659a0451a4cf992f
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

    function test_usdgToWeth() public {
        _check("usdgToWeth");
    }
}

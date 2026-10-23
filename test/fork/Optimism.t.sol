// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {ForkTest} from "../utils/ForkTest.sol";

contract OptimismForkTest is ForkTest {
    function _chainId() internal pure override returns (uint256) {
        return 10;
    }

    function _name() internal pure override returns (string memory) {
        return "optimism";
    }

    function _rpcVar() internal pure override returns (string memory) {
        return "OPTIMISM_RPC_URL";
    }

    function _pins() internal pure override returns (Pin[] memory p) {
        p = new Pin[](11);
        // Aero volatile factory
        p[0] = Pin(
            0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2,
            0xbb6f945479608857a220f9643db76e877f1e52844d953d980c18f5ea38d9574b
        );
        // Aero stable factory
        p[1] = Pin(
            0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D,
            0xd3799dedbfe65478b3e321b709d9206e88243fbfa9064b9ca3a7d03a49989471
        );
        // Aero CLFactory
        p[2] = Pin(
            0xfeaB42D90055db3a0616249f76B6002D72266778,
            0x68e96345f7fdc80c927fd25a04f6f5846cdd00173f031eae7517722a67103c7a
        );
        // UniswapV2Factory
        p[3] = Pin(
            0x0c3c1c532F1e39EdF36BE9Fe0bE1410313E074Bf,
            0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0
        );
        // UniswapV3Factory
        p[4] = Pin(
            0x1F98431c8aD98523631AE4a59f267346ea31F984,
            0x4d7b8525cd5d14343fa67a732fba5b24cddba11620ca88392f4ec6c52f91fd69
        );
        // PoolManager
        p[5] = Pin(
            0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3,
            0xa17a06da5d39984d2a3ef2704e090496d7f3658a65fda0b81c5cd6e809e5c5e4
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
            0x3064a620b37842c2e0ff3ea7619d7eac49197bd4b247955e7250250dc1ae1239
        );
        // Aero FactoryRegistry
        p[10] = Pin(
            0xb6F9705A631CC1C0E8570FFde48882C95E2Df408,
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

    function test_usdcToWeth() public {
        _check("usdcToWeth");
    }
}

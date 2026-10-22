// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {ForkTest} from "../utils/ForkTest.sol";

contract ArbitrumForkTest is ForkTest {
    function _chainId() internal pure override returns (uint256) {
        return 42161;
    }

    function _name() internal pure override returns (string memory) {
        return "arbitrum";
    }

    function _rpcVar() internal pure override returns (string memory) {
        return "ARBITRUM_RPC_URL";
    }

    function _pins() internal pure override returns (Pin[] memory p) {
        p = new Pin[](11);
        // Aero volatile factory
        p[0] = Pin(
            0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2,
            0x8fa15c35a133b821f880208b467be3224edba0811edcd002876bf8d53cf6ff35
        );
        // Aero stable factory
        p[1] = Pin(
            0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D,
            0xb9e3a337a90bf6870d95f3394be419367c402027a877e4b5c178fe102b447f0c
        );
        // Aero CLFactory
        p[2] = Pin(
            0x88a60ee77392577c355C0acb2A8d476D5a4EC03a,
            0x4cb82764ba4fd4a80c986952190a6052747a816a6dc5c7be3fc3a7a7b1bd0af4
        );
        // UniswapV2Factory
        p[3] = Pin(
            0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9,
            0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0
        );
        // UniswapV3Factory
        p[4] = Pin(
            0x1F98431c8aD98523631AE4a59f267346ea31F984,
            0x4d7b8525cd5d14343fa67a732fba5b24cddba11620ca88392f4ec6c52f91fd69
        );
        // PoolManager
        p[5] = Pin(
            0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32,
            0xe4b2759e456c9c4ef763e3b4e257c5105e1ba283d7de8b131dd321197de794a4
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
            0xbc9d92d8836ab8e1216cec5321922fe861b31bc2aa4906bc934500aa0d2dad47
        );
        // Aero FactoryRegistry
        p[10] = Pin(
            0x9E635b2c689fC52201DF7eF1C9FA607c2F58f666,
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

    function test_wethToCbBtc() public {
        _check("wethToCbBtc");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Vm} from "forge-std/Vm.sol";

import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";
import {SwapperTestBase} from "./utils/SwapperTestBase.sol";

contract SurfaceTest is SwapperTestBase {
    function test_abi() public view {
        string memory json = vm.readFile("out/ImmutableSwapper.sol/ImmutableSwapper.json");
        string[12] memory expected = [
            "constructor  nonpayable",
            "function FEE_BPS view",
            "function MAX_HOPS view",
            "function TREASURY view",
            "function algebraSwapCallback nonpayable",
            "function exchanges view",
            "function outputToken view",
            "function quote nonpayable",
            "function runRoute nonpayable",
            "function swap nonpayable",
            "function uniswapV3SwapCallback nonpayable",
            "function unlockCallback nonpayable"
        ];
        uint256 n;
        for (uint256 i;; ++i) {
            string memory key = string.concat(".abi[", vm.toString(i), "]");
            if (!vm.keyExistsJson(json, key)) break;
            string memory kind = vm.parseJsonString(json, string.concat(key, ".type"));
            if (vm.contains(kind, "event") || vm.contains(kind, "error")) continue;
            string memory name = vm.keyExistsJson(json, string.concat(key, ".name"))
                ? vm.parseJsonString(json, string.concat(key, ".name"))
                : "";
            string memory mutability = vm.parseJsonString(json, string.concat(key, ".stateMutability"));
            assertEq(string.concat(kind, " ", name, " ", mutability), expected[n++]);
        }
        assertEq(n, expected.length);
    }

    function test_constants() public view {
        assertEq(swapper.TREASURY(), 0x450c72de8c0079B49AcedF294a13011bd09D125B);
        assertEq(swapper.FEE_BPS(), 100);
        assertEq(swapper.MAX_HOPS(), 3);
    }

    function test_constructor_storesConfiguration() public view {
        assertEq(swapper.outputToken(), address(usdc));
        ImmutableSwapper.Exchange[] memory list = swapper.exchanges();
        assertEq(list.length, EXCHANGES);
        assertEq(abi.encode(list), abi.encode(_exchanges()));
    }

    function test_constructor_revertsOnZeroAddress() public {
        ImmutableSwapper.Exchange[] memory list = _exchanges();
        vm.expectRevert(ImmutableSwapper.ZeroAddress.selector);
        new ImmutableSwapper(address(0), list);
        for (uint256 i; i < EXCHANGES; ++i) {
            list = _exchanges();
            list[i].factory = address(0);
            vm.expectRevert(ImmutableSwapper.ZeroAddress.selector);
            new ImmutableSwapper(address(usdc), list);
        }
    }

    function test_constructor_revertsOnADuplicateFactory() public {
        ImmutableSwapper.Exchange[] memory list = _exchanges();
        for (uint256 i = 1; i < EXCHANGES; ++i) {
            list = _exchanges();
            list[i].factory = list[i - 1].factory;
            vm.expectRevert(ImmutableSwapper.DuplicateFactory.selector);
            new ImmutableSwapper(address(usdc), list);
        }
        list = _exchanges();
        list[EXCHANGES - 1] = ImmutableSwapper.Exchange(ImmutableSwapper.Kind.UniswapV4, address(manager));
        vm.expectRevert(ImmutableSwapper.DuplicateFactory.selector);
        new ImmutableSwapper(address(usdc), list);
    }

    function test_constructor_takesOneToTwelveExchanges() public {
        vm.expectRevert(ImmutableSwapper.BadExchangeCount.selector);
        new ImmutableSwapper(address(usdc), _anyExchanges(0));
        vm.expectRevert(ImmutableSwapper.BadExchangeCount.selector);
        new ImmutableSwapper(address(usdc), _anyExchanges(13));

        uint256[2] memory counts = [uint256(1), 12];
        for (uint256 i; i < counts.length; ++i) {
            ImmutableSwapper.Exchange[] memory list = _anyExchanges(counts[i]);
            ImmutableSwapper deployed = new ImmutableSwapper(address(usdc), list);
            assertEq(abi.encode(deployed.exchanges()), abi.encode(list), "every kind and factory, in order");
        }
    }

    function _anyExchanges(uint256 n) internal returns (ImmutableSwapper.Exchange[] memory list) {
        list = new ImmutableSwapper.Exchange[](n);
        for (uint256 i; i < n; ++i) {
            list[i] = ImmutableSwapper.Exchange(
                ImmutableSwapper.Kind(i % 7), makeAddr(string.concat("factory", vm.toString(i)))
            );
        }
    }

    function test_storage_neverTouched() public {
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](EXCHANGES);
        for (uint256 i; i < EXCHANGES; ++i) {
            routes[i] = _direct(uint8(i), address(tkn), 1e18);
        }
        _give(address(tkn), EXCHANGES * 1e18);

        vm.startStateDiffRecording();
        _swap(routes);
        Vm.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();

        uint256 touched;
        for (uint256 i; i < accesses.length; ++i) {
            for (uint256 j; j < accesses[i].storageAccesses.length; ++j) {
                if (accesses[i].storageAccesses[j].account == address(swapper)) ++touched;
            }
        }
        assertEq(touched, 0, "the swapper has no storage, only immutables and transient storage");
    }
}

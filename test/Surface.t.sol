// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Vm} from "forge-std/Vm.sol";

import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";
import {SwapperTestBase} from "./utils/SwapperTestBase.sol";

contract SurfaceTest is SwapperTestBase {
    string internal constant ARTIFACT = "out/ImmutableSwapper.sol/ImmutableSwapper.json";

    function test_abi_functionsAndWhatTheyWrite() public view {
        string memory json = vm.readFile(ARTIFACT);
        string[] memory writers = new string[](16);
        string[] memory readers = new string[](16);
        uint256 w;
        uint256 r;
        for (uint256 i;; ++i) {
            string memory key = string.concat(".abi[", vm.toString(i), "]");
            if (!vm.keyExistsJson(json, key)) break;
            string memory kind = vm.parseJsonString(json, string.concat(key, ".type"));
            assertTrue(!vm.contains(kind, "receive") && !vm.contains(kind, "fallback"), kind);
            if (keccak256(bytes(kind)) == keccak256("constructor")) {
                assertEq(vm.parseJsonString(json, string.concat(key, ".stateMutability")), "nonpayable");
            }
            if (keccak256(bytes(kind)) != keccak256("function")) continue;
            string memory name = vm.parseJsonString(json, string.concat(key, ".name"));
            string memory mutability = vm.parseJsonString(json, string.concat(key, ".stateMutability"));
            if (keccak256(bytes(mutability)) == keccak256("view") || keccak256(bytes(mutability)) == keccak256("pure"))
            {
                readers[r++] = name;
            } else {
                assertEq(mutability, "nonpayable", name);
                writers[w++] = name;
            }
        }
        string[6] memory expectedWriters =
            ["algebraSwapCallback", "quote", "runRoute", "swap", "uniswapV3SwapCallback", "unlockCallback"];
        assertEq(w, expectedWriters.length);
        for (uint256 i; i < w; ++i) {
            assertEq(writers[i], expectedWriters[i]);
        }
        string[5] memory expectedReaders = ["FEE_BPS", "MAX_HOPS", "TREASURY", "exchanges", "outputToken"];
        assertEq(r, expectedReaders.length);
        for (uint256 i; i < r; ++i) {
            assertEq(readers[i], expectedReaders[i]);
        }
    }

    function test_constants() public view {
        assertEq(swapper.TREASURY(), 0x450c72de8c0079B49AcedF294a13011bd09D125B);
        assertEq(swapper.FEE_BPS(), 100);
        assertEq(swapper.MAX_HOPS(), 3);
    }

    function test_constructor_storesConfiguration() public view {
        assertEq(swapper.outputToken(), address(usdc));
        address[] memory list = swapper.exchanges();
        address[EXCHANGES] memory expected = _exchanges();
        assertEq(list.length, EXCHANGES);
        for (uint256 i; i < EXCHANGES; ++i) {
            assertEq(list[i], expected[i]);
        }
    }

    function test_noReceiveFallbackOrPayable() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(swapper).call{value: 1}("");
        assertFalse(ok);
        (ok,) = address(swapper).call(hex"deadbeef");
        assertFalse(ok);
        (ok,) = address(swapper).call{value: 1}(abi.encodeCall(ImmutableSwapper.exchanges, ()));
        assertFalse(ok);
        ImmutableSwapper.Route[] memory routes = _routes(_direct(ImmutableSwapper.Exchange.UniswapV3, address(tkn), 1));
        (ok,) = address(swapper).call{value: 1}(abi.encodeCall(ImmutableSwapper.swap, (routes, block.timestamp, true)));
        assertFalse(ok);
    }

    function test_storage_nothingPersistentIsEverWritten() public {
        ImmutableSwapper.Exchange[] memory all = _all();
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](all.length);
        for (uint256 i; i < all.length; ++i) {
            routes[i] = _direct(all[i], address(tkn), 1e18);
        }
        _give(address(tkn), all.length * 1e18);

        vm.startStateDiffRecording();
        _quote(routes);
        _swap(routes);
        Vm.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();

        uint256 reads;
        for (uint256 i; i < accesses.length; ++i) {
            for (uint256 j; j < accesses[i].storageAccesses.length; ++j) {
                Vm.StorageAccess memory s = accesses[i].storageAccesses[j];
                if (s.account != address(swapper)) continue;
                ++reads;
                assertFalse(s.isWrite);
            }
        }
        assertEq(reads, 0, "the swapper has no storage, only immutables and transient storage");
    }
}

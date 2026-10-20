// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";
import {Deploy} from "./Deploy.s.sol";

contract Hashes is Deploy {
    function record() external returns (address predicted) {
        predicted = predict();
        string memory artifact = vm.readFile("out/ImmutableSwapper.sol/ImmutableSwapper.json");
        ImmutableSwapper local = new ImmutableSwapper{salt: keccak256("Hashes")}(USDC, exchanges());

        address[12] memory list = exchanges();
        address[] memory factories = new address[](list.length);
        for (uint256 i; i < list.length; ++i) {
            factories[i] = list[i];
        }

        string memory dep = "deployment";
        string memory depJson = vm.serializeAddress(dep, "usdc", USDC);
        depJson = vm.serializeAddress(dep, "exchanges", factories);
        depJson = vm.serializeBytes(dep, "constructorArgs", constructorArgs());
        depJson = vm.serializeAddress(dep, "address", predicted);
        depJson = vm.serializeBytes32(dep, "runtimeKeccak", keccak256(address(local).code));

        string memory root = "hashes";
        string memory json = vm.serializeString(root, "contract", "src/ImmutableSwapper.sol:ImmutableSwapper");
        json = vm.serializeString(root, "solc", vm.parseJsonString(artifact, ".metadata.compiler.version"));
        json = vm.serializeAddress(root, "create2Deployer", CREATE2_FACTORY);
        json = vm.serializeString(root, "saltPreimage", SALT_PREIMAGE);
        json = vm.serializeBytes32(root, "salt", SALT);
        json = vm.serializeBytes32(root, "creationCodeKeccak", keccak256(type(ImmutableSwapper).creationCode));
        json = vm.serializeString(root, "deployment", depJson);
        vm.writeJson(json, "verification/bytecode-hashes.json");
    }
}

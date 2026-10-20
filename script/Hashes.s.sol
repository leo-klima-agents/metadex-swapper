// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";
import {Deploy} from "./Deploy.s.sol";

contract Hashes is Deploy {
    function record() external {
        string memory artifact = vm.readFile("out/ImmutableSwapper.sol/ImmutableSwapper.json");
        address[5] memory o = outputs();
        string[5] memory s = symbols();
        string memory deployments;
        ImmutableSwapper local;
        for (uint256 i; i < o.length; ++i) {
            local = new ImmutableSwapper(o[i], exchanges());
            vm.serializeAddress(s[i], "outputToken", o[i]);
            vm.serializeBytes(s[i], "constructorArgs", constructorArgs(o[i]));
            vm.serializeAddress(s[i], "address", predict(o[i]));
            string memory one = vm.serializeBytes32(s[i], "runtimeKeccak", keccak256(address(local).code));
            deployments = vm.serializeString("deployments", s[i], one);
        }

        string memory root = "hashes";
        string memory json = vm.serializeString(root, "contract", "src/ImmutableSwapper.sol:ImmutableSwapper");
        json = vm.serializeString(root, "solc", vm.parseJsonString(artifact, ".metadata.compiler.version"));
        json = vm.serializeAddress(root, "create2Deployer", CREATE2_FACTORY);
        json = vm.serializeString(root, "saltPreimage", SALT_PREIMAGE);
        json = vm.serializeBytes32(root, "salt", SALT);
        json = vm.serializeBytes32(root, "creationCodeKeccak", keccak256(type(ImmutableSwapper).creationCode));
        json = vm.serializeAddress(root, "exchanges", local.exchanges());
        json = vm.serializeString(root, "deployments", deployments);
        vm.writeJson(json, "verification/bytecode-hashes.json");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";
import {Deploy} from "./Deploy.s.sol";

contract Hashes is Deploy {
    function record(string memory path) external {
        string memory artifact = vm.readFile("out/ImmutableSwapper.sol/ImmutableSwapper.json");
        uint256[] memory ids = chains();
        string memory all;
        for (uint256 c; c < ids.length; ++c) {
            uint256 id = ids[c];
            Config memory cfg = config(id);
            ImmutableSwapper local;
            string memory deployments;
            for (uint256 i; i < cfg.outputs.length; ++i) {
                Output memory o = cfg.outputs[i];
                string memory key = string.concat(cfg.name, ".", o.symbol);
                local = new ImmutableSwapper(o.token, cfg.exchanges);
                vm.serializeAddress(key, "outputToken", o.token);
                vm.serializeBytes(key, "constructorArgs", constructorArgs(id, o.token));
                vm.serializeAddress(key, "address", predict(id, o.token));
                string memory one = vm.serializeBytes32(key, "runtimeKeccak", keccak256(address(local).code));
                deployments = vm.serializeString(string.concat(cfg.name, ".deployments"), o.symbol, one);
            }
            // What the deployed code reports, not what the config says.
            ImmutableSwapper.Exchange[] memory e = local.exchanges();
            string[] memory kinds = new string[](e.length);
            address[] memory factories = new address[](e.length);
            for (uint256 i; i < e.length; ++i) {
                kinds[i] = kindName(e[i].kind);
                factories[i] = e[i].factory;
            }
            vm.serializeUint(cfg.name, "chainId", id);
            vm.serializeString(cfg.name, "kinds", kinds);
            vm.serializeAddress(cfg.name, "factories", factories);
            string memory chain = vm.serializeString(cfg.name, "deployments", deployments);
            all = vm.serializeString("chains", cfg.name, chain);
        }

        string memory root = "hashes";
        string memory json = vm.serializeString(root, "contract", "src/ImmutableSwapper.sol:ImmutableSwapper");
        json = vm.serializeString(root, "solc", vm.parseJsonString(artifact, ".metadata.compiler.version"));
        json = vm.serializeAddress(root, "create2Deployer", CREATE2_FACTORY);
        json = vm.serializeString(root, "saltPreimage", SALT_PREIMAGE);
        json = vm.serializeBytes32(root, "salt", SALT);
        json = vm.serializeBytes32(root, "creationCodeKeccak", keccak256(type(ImmutableSwapper).creationCode));
        json = vm.serializeString(root, "chains", all);
        vm.writeJson(json, path);
    }
}

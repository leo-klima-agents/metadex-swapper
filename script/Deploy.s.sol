// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";

contract Deploy is Script {
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant HYDREX_ALGEBRA = 0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E;
    address public constant HYDREX_CLASSIC = 0xC47F17c4fd96F50eFD2A2448ceDe5C185c084bf0;
    address public constant AERO_VOLATILE = 0x9bc8b3F60D349d687Fb44A018967025E3741F9a5;
    address public constant AERO_STABLE = 0xaEd253F1aD84d99f2165256D701b2b481DD4CC16;
    address public constant AERO_SLIPSTREAM = 0xC6bdE6e9F0CD71013E5FcF2dAAE2fA1c71Bb2F25;
    address public constant AERODROME_CLASSIC = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address public constant AERODROME_SLIPSTREAM = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
    address public constant AERODROME_SLIPSTREAM_2 = 0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a;
    address public constant AERODROME_SLIPSTREAM_3 = 0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef;
    address public constant UNISWAP_V2 = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
    address public constant UNISWAP_V3 = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address public constant UNISWAP_V4 = 0x498581fF718922c3f8e6A244956aF099B2652b2b;

    string public constant SALT_PREIMAGE = "metadex-swapper/ImmutableSwapper/v1";
    bytes32 public constant SALT = keccak256(bytes(SALT_PREIMAGE));

    // In the order of ImmutableSwapper.Exchange.
    function exchanges() public pure returns (address[12] memory) {
        return [
            HYDREX_ALGEBRA,
            HYDREX_CLASSIC,
            AERO_VOLATILE,
            AERO_STABLE,
            AERO_SLIPSTREAM,
            AERODROME_CLASSIC,
            AERODROME_SLIPSTREAM,
            AERODROME_SLIPSTREAM_2,
            AERODROME_SLIPSTREAM_3,
            UNISWAP_V2,
            UNISWAP_V3,
            UNISWAP_V4
        ];
    }

    function constructorArgs() public pure returns (bytes memory) {
        return abi.encode(USDC, exchanges());
    }

    function initCode() public pure returns (bytes memory) {
        return bytes.concat(type(ImmutableSwapper).creationCode, constructorArgs());
    }

    function predict() public pure returns (address) {
        return vm.computeCreate2Address(SALT, keccak256(initCode()), CREATE2_FACTORY);
    }

    function run() external returns (address deployed) {
        require(block.chainid == 8453, "not Base");
        require(CREATE2_FACTORY.code.length != 0, "CREATE2 deployer not present");
        deployed = predict();
        console.log("ImmutableSwapper", deployed);
        require(
            deployed == vm.parseJsonAddress(vm.readFile("verification/bytecode-hashes.json"), ".deployment.address"),
            "build differs from verification/bytecode-hashes.json"
        );
        if (deployed.code.length != 0) {
            console.log("already deployed");
            return deployed;
        }
        vm.startBroadcast();
        (bool ok,) = CREATE2_FACTORY.call(bytes.concat(SALT, initCode()));
        vm.stopBroadcast();
        require(ok && deployed.code.length != 0, "CREATE2 deploy failed");
        console.log("deployed");
    }
}

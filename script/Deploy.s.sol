// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";

contract Deploy is Script {
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    // Aero's token since its v3, not Aerodrome's AERO.
    address public constant AERO = 0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee;
    address public constant HYDX = 0x00000e7efa313F4E11Bfff432471eD9423AC6B30;

    address public constant HYDREX_ALGEBRA = 0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E;
    address public constant HYDREX_CLASSIC = 0xC47F17c4fd96F50eFD2A2448ceDe5C185c084bf0;
    address public constant AERO_VOLATILE = 0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2;
    address public constant AERO_STABLE = 0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D;
    address public constant AERO_SLIPSTREAM = 0x9CB220581b91b0C83223012FE69688b92aD07a76;
    address public constant AERODROME_CLASSIC = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address public constant AERODROME_SLIPSTREAM = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
    address public constant AERODROME_SLIPSTREAM_2 = 0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a;
    address public constant AERODROME_SLIPSTREAM_3 = 0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef;
    address public constant UNISWAP_V2 = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
    address public constant UNISWAP_V3 = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address public constant UNISWAP_V4 = 0x498581fF718922c3f8e6A244956aF099B2652b2b;

    string public constant SALT_PREIMAGE = "metadex.cafe/ImmutableSwapper/v1";
    bytes32 public constant SALT = keccak256(bytes(SALT_PREIMAGE));

    function outputs() public pure returns (address[6] memory) {
        return [USDC, EURC, WETH, CBBTC, AERO, HYDX];
    }

    function symbols() public pure returns (string[6] memory) {
        return ["USDC", "EURC", "WETH", "cbBTC", "AERO", "HYDX"];
    }

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

    function constructorArgs(address outputToken) public pure returns (bytes memory) {
        return abi.encode(outputToken, exchanges());
    }

    function initCode(address outputToken) public pure returns (bytes memory) {
        return bytes.concat(type(ImmutableSwapper).creationCode, constructorArgs(outputToken));
    }

    function predict(address outputToken) public pure returns (address) {
        return vm.computeCreate2Address(SALT, keccak256(initCode(outputToken)), CREATE2_FACTORY);
    }

    function run() external returns (address[6] memory deployed) {
        require(block.chainid == 8453, "not Base");
        require(CREATE2_FACTORY.code.length != 0, "CREATE2 deployer not present");
        string memory recorded = vm.readFile("verification/bytecode-hashes.json");
        address[6] memory o = outputs();
        string[6] memory s = symbols();
        for (uint256 i; i < o.length; ++i) {
            deployed[i] = predict(o[i]);
            console.log(s[i], deployed[i]);
            require(
                deployed[i] == vm.parseJsonAddress(recorded, string.concat(".deployments.", s[i], ".address")),
                "build differs from verification/bytecode-hashes.json"
            );
        }
        for (uint256 i; i < o.length; ++i) {
            if (deployed[i].code.length != 0) {
                console.log(s[i], "already deployed");
                continue;
            }
            vm.broadcast();
            (bool ok,) = CREATE2_FACTORY.call(bytes.concat(SALT, initCode(o[i])));
            require(ok && deployed[i].code.length != 0, "CREATE2 deploy failed");
            console.log(s[i], "deployed");
        }
    }
}

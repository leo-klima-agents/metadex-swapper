// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Test} from "forge-std/Test.sol";

import {Deploy} from "../script/Deploy.s.sol";
import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";

contract DeployTest is Test {
    Deploy internal d;

    function setUp() public {
        vm.chainId(8453);
        d = new Deploy();
    }

    function test_canonicalValues() public view {
        assertEq(d.USDC(), 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        address[12] memory e = d.exchanges();
        assertEq(e[0], 0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E, "Hydrex Algebra factory");
        assertEq(e[1], 0xC47F17c4fd96F50eFD2A2448ceDe5C185c084bf0, "Hydrex pair factory");
        assertEq(e[2], 0x9bc8b3F60D349d687Fb44A018967025E3741F9a5, "Aero volatile factory");
        assertEq(e[3], 0xaEd253F1aD84d99f2165256D701b2b481DD4CC16, "Aero stable factory");
        assertEq(e[4], 0xC6bdE6e9F0CD71013E5FcF2dAAE2fA1c71Bb2F25, "Aero CLFactory");
        assertEq(e[5], 0x420DD381b31aEf6683db6B902084cB0FFECe40Da, "Aerodrome PoolFactory");
        assertEq(e[6], 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A, "Aerodrome CLFactory");
        assertEq(e[7], 0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a, "Aerodrome second CLFactory");
        assertEq(e[8], 0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef, "Aerodrome third CLFactory");
        assertEq(e[9], 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6, "UniswapV2Factory");
        assertEq(e[10], 0x33128a8fC17869897dcE68Ed026d694621f6FDfD, "UniswapV3Factory");
        assertEq(e[11], 0x498581fF718922c3f8e6A244956aF099B2652b2b, "Uniswap v4 PoolManager");
        assertEq(d.SALT(), keccak256("metadex-swapper/ImmutableSwapper/v1"));
    }

    function test_recordMatchesScript() public {
        string memory json = vm.readFile("verification/bytecode-hashes.json");
        assertEq(vm.parseJsonString(json, ".contract"), "src/ImmutableSwapper.sol:ImmutableSwapper");
        assertEq(vm.parseJsonAddress(json, ".create2Deployer"), CREATE2_FACTORY);
        assertEq(vm.parseJsonString(json, ".saltPreimage"), d.SALT_PREIMAGE());
        assertEq(vm.parseJsonBytes32(json, ".salt"), d.SALT());
        assertEq(vm.parseJsonBytes32(json, ".creationCodeKeccak"), keccak256(type(ImmutableSwapper).creationCode));

        ImmutableSwapper local = new ImmutableSwapper(d.USDC(), d.exchanges());
        assertEq(vm.parseJsonAddress(json, ".deployment.usdc"), d.USDC());
        address[] memory recorded = vm.parseJsonAddressArray(json, ".deployment.exchanges");
        address[12] memory e = d.exchanges();
        assertEq(recorded.length, e.length);
        for (uint256 i; i < e.length; ++i) {
            assertEq(recorded[i], e[i]);
        }
        assertEq(vm.parseJsonBytes(json, ".deployment.constructorArgs"), d.constructorArgs());
        assertEq(vm.parseJsonAddress(json, ".deployment.address"), d.predict());
        assertEq(vm.parseJsonBytes32(json, ".deployment.runtimeKeccak"), keccak256(address(local).code));
    }

    function test_run_deploysAtPredictedAddress() public {
        address predicted = d.predict();
        assertEq(predicted.code.length, 0);

        assertEq(d.run(), predicted);

        ImmutableSwapper s = ImmutableSwapper(predicted);
        assertEq(s.usdc(), d.USDC());
        address[] memory list = s.exchanges();
        address[12] memory e = d.exchanges();
        assertEq(list.length, e.length);
        for (uint256 i; i < e.length; ++i) {
            assertEq(list[i], e[i]);
        }
    }

    function test_run_isIdempotent() public {
        address first = d.run();
        bytes32 codehash = first.codehash;

        assertEq(d.run(), first);
        assertEq(first.codehash, codehash);
    }

    function test_run_failsWithoutDeployer() public {
        vm.etch(CREATE2_FACTORY, "");
        vm.expectRevert(bytes("CREATE2 deployer not present"));
        d.run();
    }

    function test_run_failsOffBase() public {
        vm.chainId(1);
        vm.expectRevert(bytes("not Base"));
        d.run();
    }

    function test_constructor_revertsOnZeroAddress() public {
        address usdc = d.USDC();
        address[12] memory e = d.exchanges();
        vm.expectRevert(ImmutableSwapper.ZeroAddress.selector);
        new ImmutableSwapper(address(0), e);
        for (uint256 i; i < 12; ++i) {
            e = d.exchanges();
            e[i] = address(0);
            vm.expectRevert(ImmutableSwapper.ZeroAddress.selector);
            new ImmutableSwapper(usdc, e);
        }
    }
}

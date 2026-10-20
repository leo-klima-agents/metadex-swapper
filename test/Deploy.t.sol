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
        address[5] memory o = d.outputs();
        assertEq(o[0], 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, "USDC");
        assertEq(o[1], 0x4200000000000000000000000000000000000006, "WETH");
        assertEq(o[2], 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf, "cbBTC");
        assertEq(o[3], 0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee, "AERO, Aero's v3 token");
        assertEq(o[4], 0x00000e7efa313F4E11Bfff432471eD9423AC6B30, "HYDX");
        string[5] memory s = d.symbols();
        assertEq(s[0], "USDC");
        assertEq(s[1], "WETH");
        assertEq(s[2], "cbBTC");
        assertEq(s[3], "AERO");
        assertEq(s[4], "HYDX");

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
        assertEq(d.SALT(), keccak256("metadex.cafe/ImmutableSwapper/v1"));
    }

    function test_recordMatchesScript() public {
        string memory json = vm.readFile("verification/bytecode-hashes.json");
        assertEq(vm.parseJsonString(json, ".contract"), "src/ImmutableSwapper.sol:ImmutableSwapper");
        assertEq(vm.parseJsonAddress(json, ".create2Deployer"), CREATE2_FACTORY);
        assertEq(vm.parseJsonString(json, ".saltPreimage"), d.SALT_PREIMAGE());
        assertEq(vm.parseJsonBytes32(json, ".salt"), d.SALT());
        assertEq(vm.parseJsonBytes32(json, ".creationCodeKeccak"), keccak256(type(ImmutableSwapper).creationCode));
        address[] memory recorded = vm.parseJsonAddressArray(json, ".exchanges");
        address[12] memory e = d.exchanges();
        assertEq(recorded.length, e.length);
        for (uint256 i; i < e.length; ++i) {
            assertEq(recorded[i], e[i]);
        }

        address[5] memory o = d.outputs();
        string[5] memory s = d.symbols();
        assertEq(vm.parseJsonKeys(json, ".deployments").length, o.length);
        for (uint256 i; i < o.length; ++i) {
            string memory k = string.concat(".deployments.", s[i]);
            ImmutableSwapper local = new ImmutableSwapper(o[i], e);
            assertEq(vm.parseJsonAddress(json, string.concat(k, ".outputToken")), o[i]);
            assertEq(vm.parseJsonBytes(json, string.concat(k, ".constructorArgs")), d.constructorArgs(o[i]));
            assertEq(vm.parseJsonAddress(json, string.concat(k, ".address")), d.predict(o[i]));
            assertEq(vm.parseJsonBytes32(json, string.concat(k, ".runtimeKeccak")), keccak256(address(local).code));
        }
    }

    function test_run_deploysAtPredictedAddresses() public {
        address[5] memory o = d.outputs();
        for (uint256 i; i < o.length; ++i) {
            assertEq(d.predict(o[i]).code.length, 0);
        }

        address[5] memory deployed = d.run();

        address[12] memory e = d.exchanges();
        for (uint256 i; i < o.length; ++i) {
            assertEq(deployed[i], d.predict(o[i]));
            for (uint256 j; j < i; ++j) {
                assertTrue(deployed[j] != deployed[i]);
            }
            ImmutableSwapper s = ImmutableSwapper(deployed[i]);
            assertEq(s.outputToken(), o[i]);
            address[] memory list = s.exchanges();
            assertEq(list.length, e.length);
            for (uint256 j; j < e.length; ++j) {
                assertEq(list[j], e[j]);
            }
        }
    }

    function test_run_isIdempotent() public {
        address[5] memory first = d.run();
        bytes32 codehash = first[2].codehash;

        address[5] memory again = d.run();
        for (uint256 i; i < first.length; ++i) {
            assertEq(again[i], first[i]);
        }
        assertEq(first[2].codehash, codehash);
    }

    function test_run_deploysTheOnesMissing() public {
        address cbbtc = d.predict(d.CBBTC());
        vm.etch(d.predict(d.USDC()), hex"00");
        address[5] memory deployed = d.run();
        assertEq(deployed[2], cbbtc);
        assertEq(ImmutableSwapper(cbbtc).outputToken(), d.CBBTC());
        assertEq(deployed[0].code, hex"00", "an existing deployment is left alone");
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

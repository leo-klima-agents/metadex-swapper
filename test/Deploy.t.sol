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

        address[6] memory o = d.outputs();
        string[6] memory s = d.symbols();
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
        address[6] memory o = d.outputs();
        for (uint256 i; i < o.length; ++i) {
            assertEq(d.predict(o[i]).code.length, 0);
        }

        address[6] memory deployed = d.run();

        for (uint256 i; i < o.length; ++i) {
            assertEq(deployed[i], d.predict(o[i]));
            assertGt(deployed[i].code.length, 0);
        }
    }

    function test_run_deploysTheOnesMissing() public {
        address cbbtc = d.predict(d.CBBTC());
        vm.etch(d.predict(d.USDC()), hex"00");
        address[6] memory deployed = d.run();
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
}

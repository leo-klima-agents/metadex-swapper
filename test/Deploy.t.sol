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
        assertEq(deployed[3], cbbtc);
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

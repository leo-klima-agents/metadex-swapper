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
        vm.etch(d.TREASURY(), hex"00");
        ImmutableSwapper.Exchange[] memory e = d.exchanges(d.BASE());
        for (uint256 i; i < e.length; ++i) {
            vm.etch(e[i].factory, hex"00");
        }
        Deploy.Output[] memory o = d.outputs(d.BASE());
        for (uint256 i; i < o.length; ++i) {
            vm.etch(o[i].token, hex"00");
        }
    }

    function test_run_deploysAtPredictedAddresses() public {
        Deploy.Output[] memory o = d.outputs(d.BASE());
        for (uint256 i; i < o.length; ++i) {
            assertEq(d.predict(d.BASE(), o[i].token).code.length, 0);
        }

        address[] memory deployed = d.run();

        assertEq(deployed.length, o.length);
        for (uint256 i; i < o.length; ++i) {
            assertEq(deployed[i], d.predict(d.BASE(), o[i].token));
            ImmutableSwapper swapper = ImmutableSwapper(deployed[i]);
            assertEq(swapper.outputToken(), o[i].token);
            assertEq(abi.encode(swapper.exchanges()), abi.encode(d.exchanges(d.BASE())));
            assertEq(swapper.TREASURY(), d.TREASURY());
        }
    }

    function test_run_deploysTheOnesMissing() public {
        address cbbtc = d.predict(d.BASE(), d.CBBTC());
        vm.etch(d.predict(d.BASE(), d.USDC()), hex"00");
        address[] memory deployed = d.run();
        assertEq(deployed[3], cbbtc);
        assertEq(ImmutableSwapper(cbbtc).outputToken(), d.CBBTC());
        assertEq(deployed[0].code, hex"00", "an existing deployment is left alone");
    }

    function test_run_failsWithoutDeployer() public {
        vm.etch(CREATE2_FACTORY, "");
        vm.expectRevert(bytes("CREATE2 deployer not present"));
        d.run();
    }

    function test_run_failsWithoutTheTreasury() public {
        vm.etch(d.TREASURY(), "");
        vm.expectRevert(bytes("treasury not deployed on this chain"));
        d.run();
    }

    function test_run_failsWhenAnExchangeOrOutputHasNoCode() public {
        vm.etch(d.UNISWAP_V4(), "");
        vm.expectRevert(bytes("exchange has no code"));
        d.run();
        vm.etch(d.UNISWAP_V4(), hex"00");
        vm.etch(d.HYDX(), "");
        vm.expectRevert(bytes("output token has no code"));
        d.run();
    }

    function test_run_failsOnAnUnsupportedChain() public {
        vm.chainId(1);
        vm.expectRevert(bytes("unsupported chain"));
        d.run();
    }

    function test_config_eachChain() public view {
        uint256[] memory ids = d.chains();
        for (uint256 c; c < ids.length; ++c) {
            ImmutableSwapper.Exchange[] memory e = d.exchanges(ids[c]);
            assertGt(e.length, 0);
            assertLe(e.length, 12);
            for (uint256 i; i < e.length; ++i) {
                assertNotEq(e[i].factory, address(0));
                for (uint256 j; j < i; ++j) {
                    assertNotEq(e[i].factory, e[j].factory, "each factory once");
                }
            }
            Deploy.Output[] memory o = d.outputs(ids[c]);
            for (uint256 i; i < o.length; ++i) {
                assertNotEq(o[i].token, address(0));
                for (uint256 j; j < i; ++j) {
                    assertNotEq(o[i].token, o[j].token, "each output once");
                }
            }
        }
    }
}

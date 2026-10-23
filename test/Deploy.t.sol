// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Test} from "forge-std/Test.sol";

import {Deploy} from "../script/Deploy.s.sol";
import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";

contract DeployTest is Test {
    Deploy internal d;

    function setUp() public {
        d = new Deploy();
        _onChain(d.BASE());
    }

    function _onChain(uint256 chainId) internal returns (Deploy.Config memory c) {
        vm.chainId(chainId);
        c = d.config(chainId);
        vm.etch(d.TREASURY(), hex"00");
        for (uint256 i; i < c.exchanges.length; ++i) {
            vm.etch(c.exchanges[i].factory, hex"00");
        }
        for (uint256 i; i < c.outputs.length; ++i) {
            vm.etch(c.outputs[i].token, hex"00");
        }
    }

    function test_run_deploysEachChainAtPredictedAddresses() public {
        uint256[] memory ids = d.chains();
        for (uint256 c; c < ids.length; ++c) {
            uint256 snap = vm.snapshotState();
            Deploy.Config memory cfg = _onChain(ids[c]);
            for (uint256 i; i < cfg.outputs.length; ++i) {
                assertEq(d.predict(ids[c], cfg.outputs[i].token).code.length, 0);
            }

            address[] memory deployed = d.run();

            assertEq(deployed.length, cfg.outputs.length);
            for (uint256 i; i < cfg.outputs.length; ++i) {
                assertEq(deployed[i], d.predict(ids[c], cfg.outputs[i].token));
                ImmutableSwapper swapper = ImmutableSwapper(deployed[i]);
                assertEq(swapper.outputToken(), cfg.outputs[i].token);
                assertEq(abi.encode(swapper.exchanges()), abi.encode(cfg.exchanges), cfg.name);
                assertEq(swapper.TREASURY(), d.TREASURY());
            }
            vm.revertToState(snap);
        }
    }

    function test_run_deploysTheOnesMissing() public {
        Deploy.Output[] memory o = d.config(d.BASE()).outputs;
        address cbbtc = d.predict(d.BASE(), o[3].token);
        vm.etch(d.predict(d.BASE(), o[0].token), hex"00");
        address[] memory deployed = d.run();
        assertEq(deployed[3], cbbtc);
        assertEq(ImmutableSwapper(cbbtc).outputToken(), o[3].token);
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
        Deploy.Config memory c = d.config(d.BASE());
        vm.etch(c.exchanges[5].factory, "");
        vm.expectRevert(bytes("exchange has no code"));
        d.run();
        vm.etch(c.exchanges[5].factory, hex"00");
        vm.etch(c.outputs[5].token, "");
        vm.expectRevert(bytes("output token has no code"));
        d.run();
    }

    function test_run_failsOnAnUnsupportedChain() public {
        vm.chainId(137);
        vm.expectRevert(bytes("unsupported chain"));
        d.run();
    }

    function test_config_eachChain() public view {
        uint256[] memory ids = d.chains();
        for (uint256 c; c < ids.length; ++c) {
            Deploy.Config memory cfg = d.config(ids[c]);
            assertGt(bytes(cfg.name).length, 0);
            for (uint256 j; j < c; ++j) {
                assertNotEq(ids[c], ids[j], "each chain once");
            }
            ImmutableSwapper.Exchange[] memory e = cfg.exchanges;
            assertGt(e.length, 0);
            assertLe(e.length, 12);
            for (uint256 i; i < e.length; ++i) {
                assertNotEq(e[i].factory, address(0));
                if (i != 0) assertGe(uint256(e[i].kind), uint256(e[i - 1].kind), "exchanges in the order of Kind");
                for (uint256 j; j < i; ++j) {
                    assertNotEq(e[i].factory, e[j].factory, "each factory once");
                }
            }
            Deploy.Output[] memory o = cfg.outputs;
            assertGt(o.length, 0);
            for (uint256 i; i < o.length; ++i) {
                assertNotEq(o[i].token, address(0));
                if (i != 0) assertGt(_rank(o[i].symbol), _rank(o[i - 1].symbol), "outputs in token order");
                for (uint256 j; j < i; ++j) {
                    assertNotEq(o[i].token, o[j].token, "each output once");
                }
            }
        }
    }

    function _rank(string memory symbol) internal pure returns (uint256) {
        string[7] memory order = ["WETH", "USDC", "EURC", "cirBTC", "cbBTC", "AERO", "HYDX"];
        for (uint256 i; i < order.length; ++i) {
            if (keccak256(bytes(order[i])) == keccak256(bytes(symbol))) return i;
        }
        revert("unranked output");
    }

    function test_kindName_namesEveryKind() public view {
        string[7] memory names =
            ["AeroClassic", "AeroSlipstream", "UniswapV2", "UniswapV3", "UniswapV4", "HydrexClassic", "HydrexAlgebra"];
        for (uint256 i; i < names.length; ++i) {
            assertEq(d.kindName(ImmutableSwapper.Kind(i)), names[i]);
        }
    }
}

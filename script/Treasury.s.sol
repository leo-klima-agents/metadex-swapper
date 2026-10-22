// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface ISafeProxyFactory {
    function createProxyWithNonce(address singleton, bytes memory initializer, uint256 saltNonce)
        external
        returns (address proxy);
}

interface ISafe {
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
}

// Recreates the treasury on a chain that lacks it. It is a Safe that Safe's factory made on Base, in block 52,814,397,
// with the setup below; the same call makes it at the same address, with the same owners, on any chain that has these
// Safe contracts, whoever sends it.
contract Treasury is Script {
    address public constant TREASURY = 0x450c72de8c0079B49AcedF294a13011bd09D125B;
    address public constant FACTORY = 0x14F2982D601c9458F93bd70B218933A6f8165e7b;
    address public constant SINGLETON = 0xFf51A5898e281Db6DfC7855790607438dF2ca44b;
    address public constant L2_SINGLETON = 0xEdd160fEBBD92E350D4D398fb636302fccd67C7e;
    address public constant SETUP_TO_L2 = 0x900C7589200010D6C6eCaaE5B06EBe653bc2D82a;
    address public constant FALLBACK_HANDLER = 0x3EfCBb83A4A7AfcB4F68D501E2c2203a38be77f4;
    address public constant PAYMENT_RECEIVER = 0x5afe7A11E7000000000000000000000000000000;
    uint256 public constant THRESHOLD = 2;
    uint256 public constant SALT_NONCE = 0;

    function owners() public pure returns (address[] memory list) {
        list = new address[](3);
        list[0] = 0x38F74e78B755668D13189C207851745B2fc04A62;
        list[1] = 0x2CbbBa3f77c0dFBfBc5C7Af0f3056A086B6a7807;
        list[2] = 0xA53b1a6F17189d7061f22f8E749Fe494C9E7dAE1;
    }

    function initializer() public pure returns (bytes memory) {
        return abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners(),
            THRESHOLD,
            SETUP_TO_L2,
            abi.encodeWithSignature("setupToL2(address)", L2_SINGLETON),
            FALLBACK_HANDLER,
            address(0),
            0,
            PAYMENT_RECEIVER
        );
    }

    function run() external {
        if (TREASURY.code.length == 0) {
            address[5] memory needed = [FACTORY, SINGLETON, L2_SINGLETON, SETUP_TO_L2, FALLBACK_HANDLER];
            for (uint256 i; i < needed.length; ++i) {
                require(needed[i].code.length != 0, "Safe contracts not deployed on this chain");
            }
            vm.broadcast();
            address proxy = ISafeProxyFactory(FACTORY).createProxyWithNonce(SINGLETON, initializer(), SALT_NONCE);
            require(proxy == TREASURY, "created at another address");
            console.log("treasury created");
        }
        require(
            keccak256(abi.encode(ISafe(TREASURY).getOwners())) == keccak256(abi.encode(owners()))
                && ISafe(TREASURY).getThreshold() == THRESHOLD,
            "treasury is not the expected Safe"
        );
        console.log("treasury ok");
    }
}

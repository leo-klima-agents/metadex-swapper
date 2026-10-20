// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

interface IUnlockCallback {
    function unlockCallback(bytes calldata data) external returns (bytes memory);
}

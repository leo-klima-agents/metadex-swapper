// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

interface IPoolFactory {
    function isPool(address pool) external view returns (bool);
}

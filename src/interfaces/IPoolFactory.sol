// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

// Aero's and Aerodrome's factories, classic and Slipstream.
interface IPoolFactory {
    function isPool(address pool) external view returns (bool);
}

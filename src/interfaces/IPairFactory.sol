// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

interface IPairFactory {
    function isPair(address pair) external view returns (bool);
}

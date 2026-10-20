// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

// Answers like each kind of factory: isPool, isPair, getPair, poolByPair and getPool.
contract MockFactory {
    mapping(address => bool) public isPool;
    mapping(address => mapping(address => address)) public getPair;
    mapping(address => mapping(address => mapping(uint24 => address))) public getPool;

    function list(address pool, address tokenA, address tokenB, uint24 fee) external {
        isPool[pool] = true;
        getPair[tokenA][tokenB] = pool;
        getPair[tokenB][tokenA] = pool;
        getPool[tokenA][tokenB][fee] = pool;
        getPool[tokenB][tokenA][fee] = pool;
    }

    function isPair(address pool) external view returns (bool) {
        return isPool[pool];
    }

    function poolByPair(address tokenA, address tokenB) external view returns (address) {
        return getPair[tokenA][tokenB];
    }
}

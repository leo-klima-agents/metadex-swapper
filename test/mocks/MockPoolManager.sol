// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {IERC20} from "../../src/interfaces/IERC20.sol";
import {IPoolManager} from "../../src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "../../src/interfaces/IUnlockCallback.sol";

contract MockPoolManager {
    uint160 internal constant MIN_SQRT_PRICE = 4295128739;
    uint160 internal constant MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342;

    struct Price {
        uint256 num;
        uint256 den;
    }

    mapping(bytes32 => Price) public prices;
    mapping(address => int256) public deltas;
    address[] internal touched;
    IPoolManager.PoolKey[] internal swapped;
    bool internal unlocked;
    address internal synced;
    uint256 internal reserve;
    uint256 public fillBps = 10_000;

    function initialize(IPoolManager.PoolKey memory key, uint256 num, uint256 den) external {
        prices[keccak256(abi.encode(key))] = Price(num, den);
    }

    function setFill(uint256 bps) external {
        fillBps = bps;
    }

    function swappedKeys() external view returns (IPoolManager.PoolKey[] memory) {
        return swapped;
    }

    function unlock(bytes calldata data) external returns (bytes memory result) {
        require(!unlocked, "AlreadyUnlocked");
        unlocked = true;
        result = IUnlockCallback(msg.sender).unlockCallback(data);
        for (uint256 i; i < touched.length; ++i) {
            require(deltas[touched[i]] == 0, "CurrencyNotSettled");
        }
        delete touched;
        unlocked = false;
    }

    function swap(IPoolManager.PoolKey memory key, IPoolManager.SwapParams memory params, bytes calldata)
        external
        returns (int256)
    {
        require(unlocked, "ManagerLocked");
        Price memory p = prices[keccak256(abi.encode(key))];
        require(p.den != 0, "PoolNotInitialized");
        require(params.amountSpecified < 0, "exact input only");
        require(params.sqrtPriceLimitX96 == (params.zeroForOne ? MIN_SQRT_PRICE + 1 : MAX_SQRT_PRICE - 1), "limit");
        swapped.push(key);
        uint256 amountIn = uint256(-params.amountSpecified) * fillBps / 10_000;
        uint256 out = params.zeroForOne ? amountIn * p.num / p.den : amountIn * p.den / p.num;
        (int128 a0, int128 a1) = params.zeroForOne
            ? (-int128(int256(amountIn)), int128(int256(out)))
            : (int128(int256(out)), -int128(int256(amountIn)));
        _account(key.currency0, a0);
        _account(key.currency1, a1);
        return (int256(a0) << 128) | int256(uint256(uint128(a1)));
    }

    function sync(address currency) external {
        synced = currency;
        reserve = IERC20(currency).balanceOf(address(this));
    }

    function settle() external payable returns (uint256 paid) {
        paid = IERC20(synced).balanceOf(address(this)) - reserve;
        _account(synced, int256(paid));
        synced = address(0);
    }

    function take(address currency, address to, uint256 amount) external {
        _account(currency, -int256(amount));
        IERC20(currency).transfer(to, amount);
    }

    function _account(address currency, int256 delta) internal {
        if (delta == 0) return;
        deltas[currency] += delta;
        touched.push(currency);
    }
}

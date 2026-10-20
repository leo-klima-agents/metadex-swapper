// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

// An ERC-20 that can charge a fee on transfers, call a hook on each transfer, revert, or return nothing.
contract MockToken {
    uint8 public immutable decimals;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public taxBps;
    bool public reverts;
    bool public noReturn;
    address public hookTarget;
    bytes public hookData;

    constructor(uint8 decimals_) {
        decimals = decimals_;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function setTax(uint256 bps) external {
        taxBps = bps;
    }

    function setReverts(bool reverts_) external {
        reverts = reverts_;
    }

    function setNoReturn(bool noReturn_) external {
        noReturn = noReturn_;
    }

    // Calls target with data on the next transfer.
    function arm(address target, bytes calldata data) external {
        hookTarget = target;
        hookData = data;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        return _ok();
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        _move(from, to, amount);
        return _ok();
    }

    function _move(address from, address to, uint256 amount) internal {
        require(!reverts, "MockToken: reverts");
        address target = hookTarget;
        if (target != address(0)) {
            hookTarget = address(0);
            (bool ok, bytes memory ret) = target.call(hookData);
            if (!ok) {
                assembly ("memory-safe") {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount - amount * taxBps / 10_000;
    }

    function _ok() internal view returns (bool) {
        if (noReturn) {
            assembly ("memory-safe") {
                return(0, 0)
            }
        }
        return true;
    }
}

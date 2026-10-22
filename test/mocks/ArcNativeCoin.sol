// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Vm} from "forge-std/Vm.sol";

// Arc's USDC moves native balances through precompiles at 0x1800…00 and checks its blocklist at 0x1800…01. Foundry's
// EVM has neither, so the Arc fork tests put this stand-in at both: it moves balances as the precompile would, and
// blocks nobody.
contract ArcNativeCoin {
    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function transfer(address from, address to, uint256 amount) external returns (bool) {
        VM.deal(from, from.balance - amount);
        VM.deal(to, to.balance + amount);
        return true;
    }

    function isBlocklisted(address) external pure returns (bool) {
        return false;
    }
}

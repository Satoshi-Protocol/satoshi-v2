// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Utils {
    error ZeroAddress();

    function ensureNonzeroAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Utils {
    error ZeroAddress();
    error ZeroValue();

    function ensureNonzeroAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
    }

    function ensureNonZero(uint256 val) internal pure {
        if (val == 0) revert ZeroValue();
    }
}

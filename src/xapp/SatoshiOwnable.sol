// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AppStorage} from "./storages/AppStorage.sol";

abstract contract SatoshiOwnable {
    modifier onlyOwner() {
        require(msg.sender == AppStorage.layout().owner, "Only owner");
        _;
    }

    function _owner() internal view returns (address) {
        return AppStorage.layout().owner;
    }

    function _guardian() internal view returns (address) {
        return AppStorage.layout().guardian;
    }
}

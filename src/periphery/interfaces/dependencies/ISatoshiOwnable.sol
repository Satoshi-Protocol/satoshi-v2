// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISatoshiCore} from "../core/ISatoshiCore.sol";

interface ISatoshiOwnable {
    function SATOSHI_CORE() external view returns (ISatoshiCore);

    function owner() external view returns (address);

    function guardian() external view returns (address);
}

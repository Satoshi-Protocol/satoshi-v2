// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISatoshiXApp} from "./ISatoshiXApp.sol";

interface ISatoshiOwnable {
    function SATOSHI_CORE() external view returns (ISatoshiXApp);

    function owner() external view returns (address);

    // function guardian() external view returns (address);
}

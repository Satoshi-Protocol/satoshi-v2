// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISatoshiXApp} from "./ISatoshiXApp.sol";

interface ISatoshiOwnable {
    /**
     * @notice Returns the Satoshi Core application instance
     * @return The Satoshi Core application instance
     */
    function SATOSHI_CORE() external view returns (ISatoshiXApp);

    /**
     * @notice Returns the address of the owner
     * @return The address of the owner
     */
    function owner() external view returns (address);

    // function guardian() external view returns (address);
}

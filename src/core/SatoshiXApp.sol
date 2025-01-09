// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@solidstate/contracts/access/access_control/AccessControl.sol";

// SatoshiXApp doesn't use SolidStateDiamond from SolidState's standard implementation
// due to the need to avoid unexpected fallback execution for `_getImplementation()` function, which could lead to
// undesired behavior or vulnerabilities in the protocol's logic.
import {SolidStateDiamond} from "../library/proxy/SolidStateDiamond.sol";

/**
 * @title SatoshiXAPP Diamond Proxy
 * @author Satoshi Protocol
 * @notice The core contract of Satoshi Protocol, which implemented by
 *         diamond proxy standard.
 */
// solhint-disable-next-line no-empty-blocks
contract SatoshiXApp is SolidStateDiamond, AccessControl {
    constructor() {}
}

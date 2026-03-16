// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AccessControl } from "@solidstate/contracts/access/access_control/AccessControl.sol";

// SatoshiXApp use SolidStateDiamond from SolidState's implementation
// but add `msg.data.length` check in `_getImplementation` function, which could lead to
// undesired behavior or vulnerabilities in the protocol's logic.
import { SolidStateDiamond } from "../library/proxy/SolidStateDiamond.sol";

/**
 * @title SatoshiXAPP Diamond Proxy
 * @author Satoshi Protocol
 * @notice The core contract of Satoshi Protocol, which implemented by
 *         diamond proxy standard.
 */
// solhint-disable-next-line no-empty-blocks
contract SatoshiXApp is SolidStateDiamond, AccessControl {
    // No extra logic

    }

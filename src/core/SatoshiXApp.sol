// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SolidStateDiamond} from "@solidstate/contracts/proxy/diamond/SolidStateDiamond.sol";
import {AccessControl} from "@solidstate/contracts/access/access_control/AccessControl.sol";

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

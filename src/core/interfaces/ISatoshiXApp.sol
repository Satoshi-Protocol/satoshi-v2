// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IAccessControl } from "@solidstate/contracts/access/access_control/IAccessControl.sol";
import { ISolidStateDiamond } from "@solidstate/contracts/proxy/diamond/ISolidStateDiamond.sol";

interface ISatoshiXApp is ISolidStateDiamond, IAccessControl {
// inherit from ISolidStateDiamond and IAccessControl, no additional interfaces
}

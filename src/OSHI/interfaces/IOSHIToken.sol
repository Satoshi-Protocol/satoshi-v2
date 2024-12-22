// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IOSHIToken is IERC20Metadata {
    function initialize(address owner) external;
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
}

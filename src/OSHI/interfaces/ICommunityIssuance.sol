// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOSHIToken} from "./IOSHIToken.sol";

interface ICommunityIssuance {
    event SetAllocation(address indexed receiver, uint256 amount);
    event OSHITokenSet(IOSHIToken _oshiToken);
    event SatoshiXappSet(address _satoshiXApp);

    function transferAllocatedTokens(address receiver, uint256 amount) external;
    function setAllocated(address[] calldata _recipients, uint256[] calldata _amounts) external;
    function collectAllocatedTokens(uint256 amount) external;
    function allocated(address) external view returns (uint256);
    function collected(address) external view returns (uint256);
    function satoshiXApp() external view returns (address);
    function OSHIToken() external view returns (IOSHIToken);
    function initialize(address owner, IOSHIToken _oshiToken, address _satoshiXApp) external;
}

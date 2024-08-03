// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IOSHIToken} from "./interfaces/IOSHIToken.sol";
import {ICommunityIssuance} from "./interfaces/ICommunityIssuance.sol";
import {Utils} from "../library/Utils.sol";

contract CommunityIssuance is ICommunityIssuance, UUPSUpgradeable, OwnableUpgradeable {
    address public satoshiXApp;
    IOSHIToken public OSHIToken;

    mapping(address => uint256) public allocated; // allocate to troveManagers and SP
    mapping(address => uint256) public collected;

    constructor() {
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function initialize(address owner, IOSHIToken _oshiToken, address _satoshiXApp) external initializer {
        Utils.ensureNonzeroAddress(owner);
        Utils.ensureNonzeroAddress(address(_oshiToken));
        Utils.ensureNonzeroAddress(_satoshiXApp);

        __UUPSUpgradeable_init_unchained();
        __Ownable_init_unchained(owner);
        OSHIToken = _oshiToken;
        satoshiXApp = _satoshiXApp;

        emit OSHITokenSet(_oshiToken);
        emit SatoshiXappSet(_satoshiXApp);
    }

    function setAllocated(address[] calldata _recipients, uint256[] calldata _amounts) external onlyOwner {
        require(_recipients.length == _amounts.length, "Community Issuance: Arrays must be of equal length");
        for (uint256 i; i < _recipients.length; ++i) {
            allocated[_recipients[i]] = _amounts[i];
            emit SetAllocation(_recipients[i], _amounts[i]);
        }
    }

    function transferAllocatedTokens(address receiver, uint256 amount) external {
        if (amount > 0) {
            require(collected[msg.sender] >= amount, "Community Issuance: Insufficient balance");
            collected[msg.sender] -= amount;
            OSHIToken.transfer(receiver, amount);
        }
    }

    function collectAllocatedTokens(uint256 amount) external {
        if (amount > 0) {
            require(allocated[msg.sender] >= amount, "Community Issuance: Insufficient balance");
            allocated[msg.sender] -= amount;
            collected[msg.sender] += amount;
        }
    }
}

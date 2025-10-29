// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { Utils } from "../library/Utils.sol";
import { IOSHIToken } from "./interfaces/IOSHIToken.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract OSHIToken is IOSHIToken, ERC20Upgradeable, ERC20PermitUpgradeable, UUPSUpgradeable, OwnableUpgradeable {
    // --- ERC20 Data ---
    string internal constant _NAME = "OSHI";
    string internal constant _SYMBOL = "OSHI";

    // --- Functions ---
    constructor() {
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function initialize(address owner) external override initializer {
        Utils.ensureNonzeroAddress(owner);

        __UUPSUpgradeable_init_unchained();
        __Ownable_init_unchained(owner);
        __ERC20_init(_NAME, _SYMBOL);
        __ERC20Permit_init(_NAME);
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}

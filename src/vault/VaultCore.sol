// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ISatoshiXApp} from "../core/interfaces/ISatoshiXApp.sol";
import {IVault} from "./interfaces/IVault.sol";

abstract contract VaultCore is IVault, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    address public vaultManager;
    address public debtToken;

    constructor() {
        _disableInitializers();
    }

    modifier onlyManager() {
        if (msg.sender != vaultManager) revert Unauthorized();
        _;
    }

    modifier checkInitAddress() {
        _;
        if (vaultManager == address(0)) revert VaultManagerNotSet();
        if (debtToken == address(0)) revert DebtTokenNotSet();
    }

    function initialize(bytes calldata data) external virtual checkInitAddress {
        // implemented by child contracts
    }

    function executeStrategy(bytes calldata data) external virtual;

    function executeCall(address dest, bytes calldata data) external virtual onlyManager {
        (bool success, bytes memory res) = dest.call(data);
        require(success, string(res));
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view virtual override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function transferToken(address token, address to, uint256 amount) external virtual onlyOwner {
        IERC20(token).transfer(to, amount);
        emit TokenTransferred(token, to, amount);
    }

    function decodeTokenAddress(bytes calldata data) external virtual returns (address);

    function getPosition(address token) external view virtual returns (uint256);

    function constructExitByTroveManagerData(address token, uint256 amount)
        external
        view
        virtual
        returns (bytes memory);
}

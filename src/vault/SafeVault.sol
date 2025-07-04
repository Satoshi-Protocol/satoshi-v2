// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Utils } from "../library/Utils.sol";
import { DataTypes } from "../library/interfaces/vault/DataTypes.sol";
import { VaultCore } from "./VaultCore.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SafeVault is VaultCore {
    using SafeERC20 for IERC20;

    enum Option {
        TRANSFER
    }

    mapping(address => bool) public whitelist;

    function initialize(bytes calldata data) external override checkInitAddress initializer {
        __UUPSUpgradeable_init_unchained();
        __Ownable_init(msg.sender);
        (address vaultManager_, address debtToken_) = _decodeInitializeData(data);
        Utils.ensureNonzeroAddress(vaultManager_);
        Utils.ensureNonzeroAddress(debtToken_);

        vaultManager = vaultManager_;
        debtToken = debtToken_;

        emit VaultManagerSet(vaultManager_);
    }

    function executeStrategy(bytes calldata data) external override onlyManager {
        Option option = _decodeExecuteData(data);

        if (option == Option.TRANSFER) {
            _transfer(data[32:]);
        } else {
            revert InvalidOption(uint256(option));
        }
    }

    function setWhitelist(address to, bool valid) external onlyOwner {
        Utils.ensureNonzeroAddress(to);
        whitelist[to] = valid;
    }

    function constructTransferData(address token, uint256 amount) external pure returns (bytes memory) {
        return abi.encode(Option.TRANSFER, token, amount);
    }

    function constructExitByTroveManagerData(address, uint256) external pure override returns (bytes memory) {
        revert();
    }

    function decodeTokenAddress(bytes calldata data) external pure override returns (address) {
        address token;
        Option option = _decodeExecuteData(data);
        if (option == Option.TRANSFER) {
            (token,,) = _decodeTransferData(data[32:]);
        } else {
            revert InvalidOption(uint256(option));
        }

        return token;
    }

    function getPosition(address token) public view override returns (uint256) {
        revert NotImplemented();
    }

    // --- Internal functions ---

    function _decodeInitializeData(bytes calldata data) internal pure returns (address, address) {
        return abi.decode(data, (address, address));
    }

    function _decodeExitData(bytes calldata data) internal pure returns (address, uint256) {
        return abi.decode(data, (address, uint256));
    }

    function _decodeExecuteData(bytes calldata data) internal pure returns (Option) {
        return abi.decode(data, (Option));
    }

    function _decodeTransferData(bytes memory data) internal pure returns (address, address, uint256) {
        return abi.decode(data, (address, address, uint256));
    }

    function _transfer(bytes memory data) internal {
        (address token, address to, uint256 amount) = _decodeTransferData(data);
        if (!whitelist[to]) {
            revert NotWhitelist(to);
        }
        IERC20(token).safeTransferFrom(vaultManager, to, amount);
    }
}

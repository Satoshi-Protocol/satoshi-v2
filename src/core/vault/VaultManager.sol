// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {SatoshiMath} from "../../library/SatoshiMath.sol";
import {IVault} from "../interfaces/vault/IVault.sol";
import {IVaultManager} from "../interfaces/vault/IVaultManager.sol";
import {ITroveManager} from "../../core/interfaces/ITroveManager.sol";
import {IDebtToken} from "../interfaces/IDebtToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/* 
    * @title VaultManager
    * @dev The contract is responsible for managing the vaults
    * Each TroveManager has a VaultManager
    */

contract VaultManager is IVaultManager, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    IDebtToken public debtToken;
    mapping(address => bool) public whitelistVaults;
    // vault => tokenAmount
    mapping(address => uint256) public tokenOutput;

    // for CDP vault
    mapping(address => bool) public troveManagers;

    // troveManager => vaults
    mapping(address => IVault[]) public priority;

    address public nexusYieldManager;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _debtToken, address _nexusYieldManager) external override initializer {
        __UUPSUpgradeable_init_unchained();

        debtToken = IDebtToken(_debtToken);
        nexusYieldManager = _nexusYieldManager;

        emit NexusYieldManagerSet(_nexusYieldManager);
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view virtual override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    // --- External functions ---
    function executeStrategy(address vault, bytes calldata data) external onlyOwner {
        _checkWhitelistedVault(vault);
        address token = IVault(vault).decodeTokenAddress(data);
        if (token != address(0)) {
            IERC20(token).approve(vault, type(uint256).max);
        }
        IVault(vault).executeStrategy(data);
        emit ExecuteStrategy(vault, data);
    }

    function executeCall(address vault, address dest, bytes calldata data) external onlyOwner {
        _checkWhitelistedVault(vault);
        IVault(vault).executeCall(dest, data);
        emit ExecuteCall(vault, dest, data);
    }

    function exitStrategyByTroveManager(uint256 amount) external {
        _checkTroveManager(msg.sender);
        if (amount == 0) return;

        IERC20 collateralToken = ITroveManager(msg.sender).collateralToken();

        // assign a value to balanceAfter to prevent the priority being empty
        uint256 balanceAfter = collateralToken.balanceOf(address(this));
        uint256 withdrawAmount = amount > balanceAfter ? amount - balanceAfter : 0;
        for (uint256 i; i < priority[msg.sender].length; i++) {
            if (balanceAfter >= amount) break;
            uint256 balanceBefore = collateralToken.balanceOf(address(this));
            IVault vault = priority[msg.sender][i];
            bytes memory data = vault.constructExitByTroveManagerData(address(collateralToken), withdrawAmount);
            try vault.executeStrategy(data) {
                balanceAfter = collateralToken.balanceOf(address(this));
                uint256 exitAmount = balanceAfter - balanceBefore;
                withdrawAmount -= exitAmount;
            } catch {
                continue;
            }

            emit ExitStrategy(address(vault), data);
        }

        // if the balance is still not enough
        uint256 actualTransferAmount = balanceAfter >= amount ? amount : balanceAfter;

        // transfer token to TroveManager
        collateralToken.approve(msg.sender, actualTransferAmount);
        ITroveManager(msg.sender).receiveCollFromPrivilegedVault(actualTransferAmount);
    }

    function setPriority(address troveManager_, IVault[] memory _priority) external onlyOwner {
        delete priority[troveManager_];
        for (uint256 i; i < _priority.length; i++) {
            priority[troveManager_].push(_priority[i]);
        }
        emit PrioritySet(troveManager_, _priority);
    }

    function setWhiteListVault(address vault, bool status) external onlyOwner {
        whitelistVaults[vault] = status;
        emit WhiteListVaultSet(vault, status);
    }

    function setNexusYieldManager(address nexusYieldManager_) external onlyOwner {
        nexusYieldManager = nexusYieldManager_;
        emit NexusYieldManagerSet(nexusYieldManager_);
    }

    function setTrovesManager(address troveManager_, bool status) external onlyOwner {
        troveManagers[troveManager_] = status;

        emit TroveManagerSet(troveManager_, status);
    }

    function transferCollToTroveManager(address troveManager_, uint256 amount) external onlyOwner {
        _checkTroveManager(troveManager_);
        ITroveManager(troveManager_).collateralToken().forceApprove(troveManager_, amount);
        ITroveManager(troveManager_).receiveCollFromPrivilegedVault(amount);

        emit CollateralTransferredToTroveManager(troveManager_, amount);
    }

    function transferTokenToNYM(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(nexusYieldManager, amount);
        emit TokenTransferredToNYM(token, amount);
    }

    function mintDebtToken(uint256 amount) external {
        _checkWhitelistedVault(msg.sender);
        debtToken.mint(msg.sender, amount);
    }

    function burnDebtToken(uint256 amount) external {
        _checkWhitelistedVault(msg.sender);
        debtToken.burn(msg.sender, amount);
    }

    // --- Internal functions ---

    function _checkWhitelistedVault(address _vault) internal view {
        if (!whitelistVaults[_vault]) revert VaultNotWhitelisted();
    }

    function _checkTroveManager(address _troveManager) internal view {
        if (!troveManagers[_troveManager]) revert CallerIsNotTroveManager();
    }
}

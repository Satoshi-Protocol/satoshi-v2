// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiXApp} from "../interfaces/ISatoshiXApp.sol";
import {IStrategyManager} from "../../library/interfaces/vault/IStrategyManager.sol";
import {IDelegationManager, QueuedWithdrawalParams} from "../../library/interfaces/vault/IDelegationManager.sol";
import {IStrategy} from "../../library/interfaces/vault/IStrategy.sol";
import {CDPVaultCore} from "./CDPVaultCore.sol";
import {ISatoshiXApp} from "../interfaces/ISatoshiXApp.sol";

contract PellVault is CDPVaultCore {
    address public pellStrategy;

    function initialize(bytes calldata data) external override initializer {
        __UUPSUpgradeable_init_unchained();
        (ISatoshiXApp _satoshiCore, address tokenAddress_, address vaultManager_, address pellStrategy_) =
            _decodeInitializeData(data);

        TOKEN_ADDRESS = tokenAddress_;
        vaultManager = vaultManager_;
        pellStrategy = pellStrategy_;
    }

    modifier onlyVaultManager() {
        require(msg.sender == vaultManager, "Only vault manager");
        _;
    }

    function executeStrategy(bytes calldata data) external override onlyVaultManager {
        uint256 amount = _decodeExecuteData(data);
        IERC20(TOKEN_ADDRESS).approve(strategyAddr, amount);
        // deposit token to lending
        IStrategyManager(strategyAddr).depositIntoStrategy(IStrategy(pellStrategy), IERC20(TOKEN_ADDRESS), amount);
    }

    function exitStrategy(bytes calldata data) external override onlyVaultManager returns (uint256) {
        uint256 amount = _decodeExitData(data);
        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(pellStrategy);

        uint256[] memory shares = new uint256[](1);
        shares[0] = amount;

        QueuedWithdrawalParams[] memory queuedWithdrawal = new QueuedWithdrawalParams[](1);
        queuedWithdrawal[0] =
            QueuedWithdrawalParams({strategies: strategies, shares: shares, withdrawer: address(this)});

        // withdraw token from lending
        IDelegationManager(0x230B442c0802fE83DAf3d2656aaDFD16ca1E1F66).queueWithdrawals(queuedWithdrawal);

        return amount;
    }

    function executeCall(address dest, bytes calldata data) external onlyOwner {
        (bool success, bytes memory res) = dest.call(data);
        require(success, string(res));
    }

    function constructExecuteStrategyData(uint256 amount) external pure override returns (bytes memory) {
        return abi.encode(amount);
    }

    function constructExitStrategyData(uint256 amount) external pure override returns (bytes memory) {
        return abi.encode(amount);
    }

    function _decodeInitializeData(bytes calldata data)
        internal
        pure
        returns (ISatoshiXApp, address, address, address)
    {
        return abi.decode(data, (ISatoshiXApp, address, address, address));
    }

    function _decodeExecuteData(bytes calldata data) internal pure returns (uint256 amount) {
        return abi.decode(data, (uint256));
    }

    function _decodeExitData(bytes calldata data) internal pure returns (uint256 amount) {
        return abi.decode(data, (uint256));
    }

    function getPosition() external view override returns (address, uint256) {
        return (TOKEN_ADDRESS, IStrategy(pellStrategy).userUnderlyingView(address(this)));
    }
}

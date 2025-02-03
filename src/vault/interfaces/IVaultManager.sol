// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISatoshiXApp} from "../../core/interfaces/ISatoshiXApp.sol";
import {IVault} from "./IVault.sol";
import {IDebtToken} from "../../core/interfaces/IDebtToken.sol";

interface IVaultManager {
    event WhiteListVaultSet(address vault, bool isWhitelisted);
    event PrioritySet(address troveManager, IVault[] priority);
    event CollateralTransferredToTroveManager(address troveManager, uint256 amount);
    event ExecuteStrategy(address vault, bytes data);
    event ExitStrategy(address vault, bytes data);
    event ExecuteCall(address vault, address dest, bytes data);
    event NexusYieldManagerSet(address nexusYieldManager);
    event TokenTransferredToNYM(address token, uint256 amount);
    event TroveManagerSet(address troveManager, bool status);

    error VaultNotWhitelisted();
    error CallerIsNotTroveManager();

    function executeStrategy(address, bytes calldata) external;
    function initialize(address, address) external;
    function exitStrategyByTroveManager(uint256 amount) external;
    function setPriority(address token, IVault[] memory _priority) external;
    function transferCollToTroveManager(address troveManager, uint256 amount) external;
    function setWhiteListVault(address vault, bool status) external;
    function mintDebtToken(uint256 amount) external;
    function burnDebtToken(uint256 amount) external;
    function debtToken() external view returns (IDebtToken);
}

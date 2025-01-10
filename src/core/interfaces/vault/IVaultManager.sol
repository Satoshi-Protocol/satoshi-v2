// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISatoshiXApp} from "../ISatoshiXApp.sol";
import {INYMVault} from "./INYMVault.sol";
import {IDebtToken} from "../IDebtToken.sol";

interface IVaultManager {
    event WhiteListVaultSet(address vault, bool isWhitelisted);
    event PrioritySet(address troveManager, INYMVault[] priority);
    event CollateralTransferredToTroveManager(address troveManager, uint256 amount);
    event ExecuteStrategy(address vault, bytes data);
    event ExitStrategy(address vault, bytes data);
    event ExecuteCall(address vault, address dest, bytes data);

    error VaultNotWhitelisted();
    error CallerIsNotTroveManager();

    function executeStrategy(address, bytes calldata) external;
    function initialize(ISatoshiXApp, address) external;
    function exitStrategyByTroveManager(uint256 amount) external;
    function setPriority(address token, INYMVault[] memory _priority) external;
    function transferCollToTroveManager(address troveManager, uint256 amount) external;
    function setWhiteListVault(address vault, bool status) external;
    function mintDebtToken(uint256 amount) external;
    function burnDebtToken(uint256 amount) external;
    function debtToken() external view returns (IDebtToken);
}

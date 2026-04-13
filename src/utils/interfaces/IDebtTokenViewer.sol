// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IDebtToken } from "../../core/interfaces/IDebtToken.sol";

interface IDebtTokenViewer {
    function debtToken() external view returns (IDebtToken);
    function validAmount() external view returns (uint256);
    function isValidBalance(address account) external view returns (bool);
}

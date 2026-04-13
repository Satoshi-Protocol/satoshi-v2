// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IDebtToken } from "../core/interfaces/IDebtToken.sol";
import { IDebtTokenViewer } from "./interfaces/IDebtTokenViewer.sol";

contract DebtTokenViewer is IDebtTokenViewer {
    IDebtToken public immutable debtToken;
    uint256 public immutable validAmount;

    constructor(address debtToken_, uint256 validAmount_) {
        debtToken = IDebtToken(debtToken_);
        validAmount = validAmount_;
    }

    function isValidBalance(address account) external view returns (bool) {
        uint256 balance = debtToken.balanceOf(account);
        return balance >= validAmount;
    }
}

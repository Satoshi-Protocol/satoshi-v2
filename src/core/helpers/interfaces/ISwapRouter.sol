// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { MessagingFee } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import { DebtTokenWithLz } from "../../DebtTokenWithLz.sol";
import { IDebtToken } from "../../interfaces/IDebtToken.sol";

struct LzSendParam {
    uint32 dstEid;
    bytes extraOptions;
    MessagingFee fee;
}

interface ISwapRouter {
    error InvalidZeroAddress();

    event SwapInCrossChain(
        address indexed user, address indexed asset, uint256 assetAmount, uint256 debtAmount, LzSendParam lzSendParam
    );

    function initialize(IDebtToken _debtToken, address _xApp, address _owner) external;

    function swapInCrossChain(address asset, uint256 assetAmount, LzSendParam calldata _lzSendParam) external payable;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MessagingFee} from "@layerzerolabs/oapp-upgradeable/contracts/oft/interfaces/IOFT.sol";

import {DebtToken} from "../../DebtToken.sol";

import {IBorrowerOperationsFacet} from "../../interfaces/IBorrowerOperationsFacet.sol";
import {ITroveManager} from "../../interfaces/ITroveManager.sol";
import {IWETH} from "./IWETH.sol";
// import {ILiquidationManager} from "../../interfaces/core/ILiquidationManager.sol";

struct LzSendParam {
    uint32 dstEid;
    bytes extraOptions;
    MessagingFee fee;
}

interface ISatoshiPeriphery {
    error MsgValueMismatch(uint256 msgValue, uint256 collAmount);
    error InvalidMsgValue(uint256 msgValue);
    error NativeTokenTransferFailed();
    error CannotWithdrawAndAddColl();
    error InvalidZeroAddress();
    error RefundFailed();
    error InsufficientMsgValue(uint256 msgValue, uint256 requiredValue);

    function debtToken() external view returns (DebtToken);

    function borrowerOperationsFacet() external view returns (IBorrowerOperationsFacet);

    function weth() external view returns (IWETH);

    function openTrove(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        LzSendParam calldata _lzSendParam
    ) external payable;

    function addColl(ITroveManager troveManager, uint256 _collAmount, address _upperHint, address _lowerHint)
        external
        payable;

    function withdrawColl(ITroveManager troveManager, uint256 _collWithdrawal, address _upperHint, address _lowerHint)
        external;

    function withdrawDebt(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        LzSendParam calldata _lzSendParam
    ) external;

    function repayDebt(ITroveManager troveManager, uint256 _debtAmount, address _upperHint, address _lowerHint)
        external;

    function adjustTrove(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint,
        LzSendParam calldata _lzSendParam
    ) external payable;

    // function closeTrove(ITroveManager troveManager) external;

    function redeemCollateral(
        ITroveManager troveManager,
        uint256 _debtAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFeePercentage
    ) external;

    // function liquidateTroves(
    //     ILiquidationManager liquidationManager,
    //     ITroveManager troveManager,
    //     uint256 maxTrovesToLiquidate,
    //     uint256 maxICR
    // ) external;
}

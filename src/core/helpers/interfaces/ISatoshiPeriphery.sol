// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { MessagingFee } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import { DebtTokenWithLz } from "../../DebtTokenWithLz.sol";
import { IDebtToken } from "../../interfaces/IDebtToken.sol";

import { ITroveManager } from "../../interfaces/ITroveManager.sol";

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
    error SlippageTooHigh(uint256 actual, uint256 minimum);

    event OkxRouterSet(address indexed okxRouter);
    event OkxApproveSet(address indexed okxApprove);

    function debtToken() external view returns (DebtTokenWithLz);

    function xApp() external view returns (address);

    function okxRouter() external view returns (address);

    function okxApprove() external view returns (address);

    function initialize(IDebtToken _debtToken, address _xApp, address _owner) external;

    function setOkxRouter(address _okxRouter) external;

    function setOkxApprove(address _okxApprove) external;

    function openTrove(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        LzSendParam calldata _lzSendParam
    )
        external
        payable;

    function addColl(ITroveManager troveManager, uint256 _collAmount, address _upperHint, address _lowerHint) external;

    function withdrawColl(
        ITroveManager troveManager,
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint
    )
        external;

    function withdrawDebt(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        LzSendParam calldata _lzSendParam
    )
        external
        payable;

    function repayDebt(
        ITroveManager troveManager,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    )
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
    )
        external
        payable;

    function closeTrove(ITroveManager troveManager) external;

    function liquidateTroves(
        ITroveManager troveManager,
        uint256 maxTrovesToLiquidate,
        uint256 maxICR,
        LzSendParam calldata _lzSendParam
    )
        external
        payable;

    /// @notice Swap any ERC20 → stable token via OKX DEX → DebtToken via NYM.swapIn (ERC20 only)
    /// @param fromToken          Input ERC20 token (must be approved to this contract)
    /// @param fromAmount         Raw input amount
    /// @param okxCalldata        OKX swap calldata from backend /okx/nym-swap response
    /// @param stableAsset        Stable token address from backend /okx/nym-swap response
    /// @param minDebtAmount      Minimum DebtToken to receive; revert if below this (slippage guard)
    function swapInWithOkx(
        address fromToken,
        uint256 fromAmount,
        bytes calldata okxCalldata,
        address stableAsset,
        uint256 minDebtAmount
    )
        external;
}

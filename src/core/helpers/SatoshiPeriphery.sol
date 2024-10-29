// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    IOFT,
    SendParam,
    OFTLimit,
    OFTReceipt,
    OFTFeeDetail,
    MessagingReceipt,
    MessagingFee
} from "@layerzerolabs/oapp-upgradeable/contracts/oft/interfaces/IOFT.sol";

import {IWETH} from "./interfaces/IWETH.sol";
import {IBorrowerOperationsFacet} from "../interfaces/IBorrowerOperationsFacet.sol";
import {ILiquidationFacet} from "../interfaces/ILiquidationFacet.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {DebtToken} from "../DebtToken.sol";
import {ISatoshiPeriphery, LzSendParam} from "./interfaces/ISatoshiPeriphery.sol";

import {IPriceFeed} from "../../priceFeed/IPriceFeed.sol";

import {Config} from "../Config.sol";

/**
 * @title Satoshi Borrower Operations Router
 *        Handle the native token and ERC20 for the borrower operations
 */
contract SatoshiPeriphery is ISatoshiPeriphery, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for DebtToken;

    DebtToken public debtToken;

    address public immutable xApp;
    IWETH public immutable weth;

    constructor(DebtToken _debtToken, IWETH _weth, address _xApp) {
        if (address(_debtToken) == address(0)) revert InvalidZeroAddress();
        if (_xApp == address(0)) revert InvalidZeroAddress();
        if (address(_weth) == address(0)) revert InvalidZeroAddress();

        debtToken = _debtToken;
        weth = _weth;
        xApp = _xApp;
    }

    /// @notice Open a trove
    /// @dev Account should call `setDelegateApproval()` first to approve this contract to call openTrove
    /// @param troveManager The TroveManager contract
    /// @param _maxFeePercentage User willing to accept in case of a fee slippage
    /// @param _collAmount The amount of collateral to deposit
    /// @param _debtAmount The expected debt amount of borrowed
    /// @param _upperHint The upper hint (for querying the position of the sorted trove)
    /// @param _lowerHint The lower hint (for querying the position of the sorted trove)
    function openTrove(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        LzSendParam calldata _lzSendParam
    ) external payable {
        IERC20 collateralToken = troveManager.collateralToken();

        _beforeAddColl(collateralToken, _collAmount);

        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        IBorrowerOperationsFacet(xApp).openTrove(
            troveManager, msg.sender, _maxFeePercentage, _collAmount, _debtAmount, _upperHint, _lowerHint
        );

        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiPeriphery: Debt amount mismatch");

        _afterWithdrawDebt(userDebtAmount, _lzSendParam);
    }

    /// @notice Add collateral to a active trove
    /// @param troveManager The TroveManager contract
    /// @param _collAmount The amount of additional collateral
    /// @param _upperHint The upper hint (for querying the position of the sorted trove)
    /// @param _lowerHint The lower hint (for querying the position of the sorted trove)
    function addColl(ITroveManager troveManager, uint256 _collAmount, address _upperHint, address _lowerHint)
        external
        payable
    {
        IERC20 collateralToken = troveManager.collateralToken();

        _beforeAddColl(collateralToken, _collAmount);

        IBorrowerOperationsFacet(xApp).addColl(troveManager, msg.sender, _collAmount, _upperHint, _lowerHint);
    }

    /// @notice Withdraws _collWithdrawal of collateral from the caller’s Trove
    /// @dev Executes only if the user has an active Trove,
    /// @dev Withdrawal would not pull the user’s Trove below the MCR, and the resulting total collateralization ratio of the system is above 150%(TCR)
    /// @param troveManager The TroveManager contract
    /// @param _collWithdrawal The amount of collateral to withdraw
    /// @param _upperHint The upper hint (for querying the position of the sorted trove)
    /// @param _lowerHint The lower hint (for querying the position of the sorted trove)
    function withdrawColl(ITroveManager troveManager, uint256 _collWithdrawal, address _upperHint, address _lowerHint)
        external
    {
        IERC20 collateralToken = troveManager.collateralToken();
        uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

        IBorrowerOperationsFacet(xApp).withdrawColl(troveManager, msg.sender, _collWithdrawal, _upperHint, _lowerHint);

        uint256 collTokenBalanceAfter = collateralToken.balanceOf(address(this));
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;
        require(userCollAmount == _collWithdrawal, "SatoshiPeriphery: Collateral amount mismatch");
        _afterWithdrawColl(collateralToken, userCollAmount);
    }

    /// @notice Issues _debtAmount of Debt token from the caller’s Trove to the caller.
    /// @dev Executes only if the Trove's collateralization ratio would remain above the minimum
    /// @param troveManager The TroveManager contract
    /// @param _maxFeePercentage User willing to accept in case of a fee slippage
    /// @param _debtAmount The amount of debt to withdraw
    /// @param _upperHint The upper hint (for querying the position of the sorted trove)
    /// @param _lowerHint The lower hint (for querying the position of the sorted trove)
    function withdrawDebt(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        LzSendParam calldata _lzSendParam
    ) external {
        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));
        IBorrowerOperationsFacet(xApp).withdrawDebt(
            troveManager, msg.sender, _maxFeePercentage, _debtAmount, _upperHint, _lowerHint
        );
        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiPeriphery: Debt amount mismatch");

        _afterWithdrawDebt(userDebtAmount, _lzSendParam);
    }

    /// @notice Repays _debtAmount of Debt token to the caller’s Trove
    /// @param troveManager The TroveManager contract
    /// @param _debtAmount The amount of debt to repay
    /// @param _upperHint The upper hint (for querying the position of the sorted trove)
    /// @param _lowerHint The lower hint (for querying the position of the sorted trove)
    function repayDebt(ITroveManager troveManager, uint256 _debtAmount, address _upperHint, address _lowerHint)
        external
    {
        _beforeRepayDebt(_debtAmount);

        IBorrowerOperationsFacet(xApp).repayDebt(troveManager, msg.sender, _debtAmount, _upperHint, _lowerHint);
    }

    /// @notice Enables a borrower to simultaneously change (decrease/increase) both their collateral and debt,
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
    ) external payable {
        if (_collDeposit != 0 && _collWithdrawal != 0) revert CannotWithdrawAndAddColl();

        IERC20 collateralToken = troveManager.collateralToken();
        _beforeAddColl(collateralToken, _collDeposit);

        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        // repay debt
        if (!_isDebtIncrease) {
            _beforeRepayDebt(_debtChange);
        }

        IBorrowerOperationsFacet(xApp).adjustTrove(
            troveManager,
            msg.sender,
            _maxFeePercentage,
            _collDeposit,
            _collWithdrawal,
            _debtChange,
            _isDebtIncrease,
            _upperHint,
            _lowerHint
        );

        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        // withdraw collateral
        _afterWithdrawColl(collateralToken, _collWithdrawal);

        // withdraw debt
        if (_isDebtIncrease) {
            require(
                debtTokenBalanceAfter - debtTokenBalanceBefore == _debtChange, "SatoshiPeriphery: Debt amount mismatch"
            );

            _afterWithdrawDebt(_debtChange, _lzSendParam);
        }
    }

    /// @notice Close the trove from the caller
    /// @param troveManager The TroveManager contract
    function closeTrove(ITroveManager troveManager) external {
        (uint256 collAmount, uint256 debtAmount) = troveManager.getTroveCollAndDebt(msg.sender);
        uint256 netDebtAmount = debtAmount - Config.DEBT_GAS_COMPENSATION;
        _beforeRepayDebt(netDebtAmount);

        IERC20 collateralToken = troveManager.collateralToken();
        uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

        IBorrowerOperationsFacet(xApp).closeTrove(troveManager, msg.sender);

        uint256 collTokenBalanceAfter = collateralToken.balanceOf(address(this));
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;
        require(userCollAmount == collAmount, "SatoshiPeriphery: Collateral amount mismatch");
        _afterWithdrawColl(collateralToken, userCollAmount);
    }

    function redeemCollateral(
        ITroveManager troveManager,
        uint256 _debtAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFeePercentage
    ) external {
        IERC20 collateralToken = troveManager.collateralToken();

        _beforeRepayDebt(_debtAmount);

        uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

        troveManager.redeemCollateral(
            _debtAmount,
            _firstRedemptionHint,
            _upperPartialRedemptionHint,
            _lowerPartialRedemptionHint,
            _partialRedemptionHintNICR,
            _maxIterations,
            _maxFeePercentage
        );

        uint256 collTokenBalanceAfter = collateralToken.balanceOf(address(this));
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;

        _afterWithdrawColl(collateralToken, userCollAmount);
    }

    /// @dev Only support ERC20 & WETH, if receive native tokens, function will be converted to WETH then transfer
    function _beforeAddColl(IERC20 collateralToken, uint256 collAmount) private {
        if (collAmount == 0) return;

        // TODO: Do not support native token
        if (address(collateralToken) == address(weth)) {
            if (msg.value < collAmount) revert MsgValueMismatch(msg.value, collAmount);

            weth.deposit{value: collAmount}();
        } else {
            collateralToken.safeTransferFrom(msg.sender, address(this), collAmount);
        }

        collateralToken.approve(xApp, collAmount);
    }

    function _afterWithdrawColl(IERC20 collateralToken, uint256 collAmount) private {
        if (collAmount == 0) return;

        if (address(collateralToken) == address(weth)) {
            weth.withdraw(collAmount);

            (bool success,) = payable(msg.sender).call{value: collAmount}("");
            if (!success) revert NativeTokenTransferFailed();
        } else {
            collateralToken.safeTransfer(msg.sender, collAmount);
        }
    }

    function _beforeRepayDebt(uint256 debtAmount) private {
        if (debtAmount == 0) return;

        debtToken.safeTransferFrom(msg.sender, address(this), debtAmount);
    }

    /// @notice Withdraw the debt token to the msg sender
    /// @dev Transfer the debt token in current chain if dstEid is 0
    /// @dev Only debt token need to provide lzSendParam, and support native token as lz fee
    function _afterWithdrawDebt(uint256 debtAmount, LzSendParam calldata lzSendParam) private {
        if (debtAmount == 0) return;
        address account = msg.sender;

        // In current chain
        if (lzSendParam.dstEid == 0) {
            debtToken.safeTransfer(account, debtAmount);
        } else {
            // Step 1: Prepare the SendParam
            SendParam memory _sendParam = SendParam(
                lzSendParam.dstEid,
                bytes32(uint256(uint160(account))),
                debtAmount,
                debtAmount,
                lzSendParam.extraOptions,
                "",
                ""
            );

            // Step 2: Quote the fee
            // TODO: payInLzToken
            require(lzSendParam.fee.lzTokenFee == 0, "BorrowerOps: lzTokenFee not supported");
            // TODO: check collateral token is native token?
            require(msg.value == lzSendParam.fee.nativeFee, "BorrowerOps: nativeFee not sent");

            MessagingFee memory expectFee = debtToken.quoteSend(_sendParam, lzSendParam.fee.lzTokenFee > 0);
            require(expectFee.nativeFee == lzSendParam.fee.nativeFee, "BorrowerOps: nativeFee incorrect");
            require(expectFee.lzTokenFee == lzSendParam.fee.lzTokenFee, "BorrowerOps: lzTokenFee incorrect");

            // Step 3: Send the Debt tokens to the other chain
            debtToken.send(_sendParam, lzSendParam.fee, account);
        }
    }

    //? not used
    function _refundGas() internal {
        if (address(this).balance != 0) {
            (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
            if (!success) revert RefundFailed();
        }
    }

    receive() external payable {
        // to receive native token
    }

    function liquidateTroves(
        ITroveManager troveManager,
        uint256 maxTrovesToLiquidate,
        uint256 maxICR,
        LzSendParam calldata _lzSendParam
    ) external {
        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));
        uint256 collTokenBalanceBefore = troveManager.collateralToken().balanceOf(address(this));

        ILiquidationFacet(xApp).liquidateTroves(troveManager, maxTrovesToLiquidate, maxICR);

        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 collTokenBalanceAfter = troveManager.collateralToken().balanceOf(address(this));

        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;

        _afterWithdrawDebt(userDebtAmount, _lzSendParam);
        _afterWithdrawColl(troveManager.collateralToken(), userCollAmount);
    }
}

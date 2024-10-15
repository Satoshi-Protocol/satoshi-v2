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
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {DebtToken} from "../DebtToken.sol";
import {ISatoshiPeriphery} from "./interfaces/ISatoshiPeriphery.sol";

import {IPriceFeed} from "../../priceFeed/IPriceFeed.sol";
// import {ILiquidationManager} from "../interfaces/ILiquidationManager.sol";

/**
 * @title Satoshi Borrower Operations Router
 *        Handle the native token and ERC20 for the borrower operations
 */
contract SatoshiPeriphery is ISatoshiPeriphery, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for DebtToken;

    DebtToken public debtToken;
    IBorrowerOperationsFacet public immutable borrowerOperationsProxy;
    IWETH public immutable weth;

    constructor(DebtToken _debtToken, IBorrowerOperationsFacet _borrowerOperationsProxy, IWETH _weth) {
        if (address(_debtToken) == address(0)) revert InvalidZeroAddress();
        if (address(_borrowerOperationsProxy) == address(0)) revert InvalidZeroAddress();
        if (address(_weth) == address(0)) revert InvalidZeroAddress();

        debtToken = _debtToken;
        borrowerOperationsProxy = _borrowerOperationsProxy;
        weth = _weth;
    }

    // account should call borrowerOperationsProxy.setDelegateApproval first
    // to approve this contract to call openTrove
    function openTrove(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external payable {
        IERC20 collateralToken = troveManager.collateralToken();

        _beforeAddColl(collateralToken, _collAmount);

        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        borrowerOperationsProxy.openTrove(
            troveManager, msg.sender, _maxFeePercentage, _collAmount, _debtAmount, _upperHint, _lowerHint
        );

        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiPeriphery: Debt amount mismatch");
        _afterWithdrawDebt(userDebtAmount);
    }

    function openTroveToOtherChain(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        uint32 _dstEid, // Destination endpoint ID.
        bytes calldata _extraOptions, // Additional options supplied by the caller to be used in the LayerZero message.
        MessagingFee calldata _fee
    ) external payable {
        IERC20 collateralToken = troveManager.collateralToken();

        _beforeAddColl(collateralToken, _collAmount);

        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        borrowerOperationsProxy.openTrove(
            troveManager, msg.sender, _maxFeePercentage, _collAmount, _debtAmount, _upperHint, _lowerHint
        );

        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiPeriphery: Debt amount mismatch");
        _afterWithdrawDebtForLz(userDebtAmount, _dstEid, _extraOptions, _fee);
    }

    function addColl(ITroveManager troveManager, uint256 _collAmount, address _upperHint, address _lowerHint)
        external
        payable
    {
        IERC20 collateralToken = troveManager.collateralToken();

        _beforeAddColl(collateralToken, _collAmount);

        borrowerOperationsProxy.addColl(troveManager, msg.sender, _collAmount, _upperHint, _lowerHint);
    }

    function withdrawColl(ITroveManager troveManager, uint256 _collWithdrawal, address _upperHint, address _lowerHint)
        external
    {
        IERC20 collateralToken = troveManager.collateralToken();
        uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

        borrowerOperationsProxy.withdrawColl(troveManager, msg.sender, _collWithdrawal, _upperHint, _lowerHint);

        uint256 collTokenBalanceAfter = collateralToken.balanceOf(address(this));
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;
        require(userCollAmount == _collWithdrawal, "SatoshiPeriphery: Collateral amount mismatch");
        _afterWithdrawColl(collateralToken, userCollAmount);
    }

    function withdrawDebt(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external {
        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));
        borrowerOperationsProxy.withdrawDebt(
            troveManager, msg.sender, _maxFeePercentage, _debtAmount, _upperHint, _lowerHint
        );
        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiPeriphery: Debt amount mismatch");

        _afterWithdrawDebt(userDebtAmount);
    }

    function withdrawDebtToOtherChain(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        uint32 _dstEid, // Destination endpoint ID.
        bytes calldata _extraOptions, // Additional options supplied by the caller to be used in the LayerZero message.
        MessagingFee calldata _fee
    ) external {
        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));
        borrowerOperationsProxy.withdrawDebt(
            troveManager, msg.sender, _maxFeePercentage, _debtAmount, _upperHint, _lowerHint
        );
        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiPeriphery: Debt amount mismatch");
        _afterWithdrawDebtForLz(userDebtAmount, _dstEid, _extraOptions, _fee);
    }

    function repayDebt(ITroveManager troveManager, uint256 _debtAmount, address _upperHint, address _lowerHint)
        external
    {
        _beforeRepayDebt(_debtAmount);

        borrowerOperationsProxy.repayDebt(troveManager, msg.sender, _debtAmount, _upperHint, _lowerHint);
    }

    function adjustTrove(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external payable {
        if (_collDeposit != 0 && _collWithdrawal != 0) revert CannotWithdrawAndAddColl();

        IERC20 collateralToken = troveManager.collateralToken();

        // add collateral
        _beforeAddColl(collateralToken, _collDeposit);

        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        // repay debt
        if (!_isDebtIncrease) {
            _beforeRepayDebt(_debtChange);
        }

        borrowerOperationsProxy.adjustTrove(
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

            _afterWithdrawDebt(_debtChange);
        }
    }

    // TODO: get DEBT_GAS_COMPENSATION
    // function closeTrove(ITroveManager troveManager) external {
    //     (uint256 collAmount, uint256 debtAmount) = troveManager.getTroveCollAndDebt(msg.sender);
    //     uint256 netDebtAmount = debtAmount - borrowerOperationsProxy.DEBT_GAS_COMPENSATION();
    //     _beforeRepayDebt(netDebtAmount);

    //     IERC20 collateralToken = troveManager.collateralToken();
    //     uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

    //     borrowerOperationsProxy.closeTrove(troveManager, msg.sender);

    //     uint256 collTokenBalanceAfter = collateralToken.balanceOf(address(this));
    //     uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;
    //     require(userCollAmount == collAmount, "SatoshiPeriphery: Collateral amount mismatch");
    //     _afterWithdrawColl(collateralToken, userCollAmount);
    // }

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

    function _beforeAddColl(IERC20 collateralToken, uint256 collAmount) private {
        if (collAmount == 0) return;

        if (address(collateralToken) == address(weth)) {
            if (msg.value < collAmount) revert MsgValueMismatch(msg.value, collAmount);

            weth.deposit{value: collAmount}();
        } else {
            collateralToken.safeTransferFrom(msg.sender, address(this), collAmount);
        }

        collateralToken.approve(address(borrowerOperationsProxy), collAmount);
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

    function _afterWithdrawDebt(uint256 debtAmount) private {
        if (debtAmount == 0) return;
        debtToken.safeTransfer(msg.sender, debtAmount);
    }

    function _afterWithdrawDebtForLz(
        uint256 debtAmount,
        uint32 dstEid, // Destination endpoint ID.
        bytes calldata extraOptions, // Additional options supplied by the caller to be used in the LayerZero message.
        MessagingFee calldata _fee
    ) private {
        if (debtAmount == 0) return;
        address account = msg.sender;
        // Step 2: Prepare the SendParam
        SendParam memory _sendParam =
            SendParam(dstEid, bytes32(uint256(uint160(account))), debtAmount, debtAmount, extraOptions, "", "");

        // Step 3: Quote the fee
        // TODO: payInLzToken
        require(_fee.lzTokenFee == 0, "BorrowerOps: lzTokenFee not supported");
        require(msg.value == _fee.nativeFee, "BorrowerOps: nativeFee not sent");
        MessagingFee memory expectFee = debtToken.quoteSend(_sendParam, _fee.lzTokenFee > 0);
        require(expectFee.nativeFee == _fee.nativeFee, "BorrowerOps: nativeFee incorrect");
        require(expectFee.lzTokenFee == _fee.lzTokenFee, "BorrowerOps: lzTokenFee incorrect");

        // Step 4: Send the Debt tokens to the other chain
        debtToken.send(_sendParam, _fee, account);
    }

    function _refundGas() internal {
        if (address(this).balance != 0) {
            (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
            if (!success) revert RefundFailed();
        }
    }

    receive() external payable {
        // to receive native token
    }

    // mapping(uint256 => uint256) public chainIdToEid;

    // function whiteListEid(uint256 _eid) external {
    //     chainIdToEid[CHAIN_ID] = _eid;
    // }

    // function validEid(uint256 chainId) external {
    //     require(chainIdToEid[chainId] != 0, "SatoshiPeriphery: Invalid chain id");
    // }
}

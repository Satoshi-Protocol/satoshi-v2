// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Config } from "../Config.sol";
import { DebtTokenWithLz } from "../DebtTokenWithLz.sol";
import { INexusYieldManagerFacet } from "../interfaces/INexusYieldManagerFacet.sol";

import { IDebtToken } from "../interfaces/IDebtToken.sol";
import { ISwapRouter, LzSendParam } from "./interfaces/ISwapRouter.sol";
import {
    IOFT,
    MessagingFee,
    MessagingReceipt,
    OFTFeeDetail,
    OFTLimit,
    OFTReceipt,
    SendParam
} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Satoshi Swap Router
 */
contract SwapRouter is ISwapRouter, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for DebtTokenWithLz;

    DebtTokenWithLz public debtToken;
    address public xApp;

    function initialize(IDebtToken _debtToken, address _xApp, address _owner) external initializer {
        if (address(_debtToken) == address(0)) revert InvalidZeroAddress();
        if (_xApp == address(0)) revert InvalidZeroAddress();

        debtToken = DebtTokenWithLz(address(_debtToken));
        xApp = _xApp;

        __Ownable_init(_owner);
        __UUPSUpgradeable_init_unchained();
    }

    receive() external payable {
        // to receive native token
    }

    // EXTERNAL FUNCTIONS //

    function swapInCrossChain(
        address asset,
        uint256 assetAmount,
        address receiver,
        LzSendParam calldata _lzSendParam
    )
        external
        payable
    {
        _beforeAddAsset(IERC20(asset), assetAmount);
        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        uint256 debtAmount = INexusYieldManagerFacet(xApp).swapIn(asset, address(this), assetAmount);

        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == debtAmount, "SwapRouter: Debt amount mismatch");

        _sendDebt(debtAmount, receiver, _lzSendParam);

        emit SwapInCrossChain(msg.sender, receiver, asset, assetAmount, debtAmount, _lzSendParam);
    }

    // INTERNAL FUNCTIONS //

    /// @dev Only support ERC20 token, not support native token
    function _beforeAddAsset(IERC20 token, uint256 amount) private {
        if (amount == 0) return;

        token.safeTransferFrom(msg.sender, address(this), amount);
        token.safeIncreaseAllowance(xApp, amount);
    }

    /// @notice Withdraw the debt token to the receiver
    /// @dev Need used in the payable functions
    /// @dev Transfer the debt token in current chain if dstEid is 0
    /// @dev Only debt token need to provide lzSendParam, and support native token as lz fee
    function _sendDebt(uint256 debtAmount, address receiver, LzSendParam calldata lzSendParam) private {
        if (debtAmount == 0) return;

        if (lzSendParam.dstEid == 0) {
            // In current chain
            debtToken.safeTransfer(receiver, debtAmount);
        } else if (debtToken.peers(lzSendParam.dstEid) == 0) {
            // If the dstEid is not supported, just transfer the debt token to the msg sender
            debtToken.safeTransfer(msg.sender, debtAmount);
        } else {
            // Step 1: Prepare the SendParam
            SendParam memory _sendParam = SendParam(
                lzSendParam.dstEid,
                bytes32(uint256(uint160(receiver))),
                debtAmount,
                0, /* minAmountLD */
                lzSendParam.extraOptions,
                "",
                ""
            );

            // Step 2: Quote the fee
            require(lzSendParam.fee.lzTokenFee == 0, "SwapRouter: lzTokenFee not supported");
            require(msg.value == lzSendParam.fee.nativeFee, "SwapRouter: nativeFee not sent");

            MessagingFee memory expectFee = debtToken.quoteSend(_sendParam, lzSendParam.fee.lzTokenFee > 0);
            require(expectFee.nativeFee == lzSendParam.fee.nativeFee, "SwapRouter: nativeFee incorrect");
            require(expectFee.lzTokenFee == lzSendParam.fee.lzTokenFee, "SwapRouter: lzTokenFee incorrect");

            // Step 3: Send the Debt tokens to the other chain
            debtToken.send{ value: msg.value }(_sendParam, lzSendParam.fee, msg.sender);
        }
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }
}

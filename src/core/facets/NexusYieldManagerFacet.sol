// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.19;

import { IRewardManager } from "../../OSHI/interfaces/IRewardManager.sol";
import { AppStorage } from "../AppStorage.sol";
import { Config } from "../Config.sol";
import { AssetConfig, ChainConfig, INexusYieldManagerFacet } from "../interfaces/INexusYieldManagerFacet.sol";
import { IPriceFeedAggregatorFacet } from "../interfaces/IPriceFeedAggregatorFacet.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControlInternal } from "@solidstate/contracts/access/access_control/AccessControlInternal.sol";
import { ReentrancyGuard } from "@solidstate/contracts/security/reentrancy_guard/ReentrancyGuard.sol";

/**
 * @title Nexus Yield Manager Contract.
 * Mutated from:
 * https://github.com/VenusProtocol/venus-protocol/blob/develop/contracts/PegStability/PegStability.sol
 * @notice Contract for swapping stable token for debtToken token and vice versa to maintain the peg stability between them.
 */
contract NexusYieldManagerFacet is INexusYieldManagerFacet, AccessControlInternal, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**
     * @dev Prevents functions to execute when contract is paused.
     */
    modifier isActive() {
        AppStorage.Layout storage s = AppStorage.layout();
        if (s.isNymPaused) revert Paused();
        _;
    }

    /**
     * @dev Prevents functions to execute when msg.sender is not a privileged address.
     */
    modifier onlyPrivileged() {
        AppStorage.Layout storage s = AppStorage.layout();
        require(s.isPrivileged[msg.sender], "NexusYieldManager: caller is not privileged");
        _;
    }

    function setAssetConfig(
        address asset,
        AssetConfig calldata assetConfig_
    )
        external
        onlyRole(Config.OWNER_ROLE)
    {
        AppStorage.Layout storage s = AppStorage.layout();
        if (assetConfig_.feeIn >= Config.BASIS_POINTS_DIVISOR || assetConfig_.feeOut >= Config.BASIS_POINTS_DIVISOR) {
            revert INexusYieldManagerFacet.InvalidFee(assetConfig_.feeIn, assetConfig_.feeOut);
        }
        AssetConfig storage assetConfig = s.assetConfigs[asset];
        assetConfig.decimals = assetConfig_.decimals;
        assetConfig.feeIn = assetConfig_.feeIn;
        assetConfig.feeOut = assetConfig_.feeOut;
        assetConfig.debtTokenMintCap = assetConfig_.debtTokenMintCap;
        assetConfig.dailyDebtTokenMintCap = assetConfig_.dailyDebtTokenMintCap;
        assetConfig.oracle = assetConfig_.oracle;
        assetConfig.isUsingOracle = assetConfig_.isUsingOracle;
        assetConfig.swapWaitingPeriod = assetConfig_.swapWaitingPeriod;
        assetConfig.maxPrice = assetConfig_.maxPrice;
        assetConfig.minPrice = assetConfig_.minPrice;
        s.isAssetSupported[asset] = true;

        emit AssetConfigSetting(asset, assetConfig_);
    }

    /**
     * @notice Removes support for an asset and marks it as sunset.
     * @param asset The address of the asset to sunset.
     */
    function sunsetAsset(address asset) external onlyRole(Config.OWNER_ROLE) {
        AppStorage.Layout storage s = AppStorage.layout();
        s.isAssetSupported[asset] = false;

        emit AssetSunset(asset);
    }

    /**
     * @notice Transfer the token to the privileged vault.
     * @param token The address of the token to transfer.
     * @param vault The address of the privileged vault.
     * @param amount The amount of token to transfer.
     */
    function transferTokenToPrivilegedVault(
        address token,
        address vault,
        uint256 amount
    )
        external
        onlyRole(Config.OWNER_ROLE)
    {
        AppStorage.Layout storage s = AppStorage.layout();
        if (!s.isPrivileged[vault]) {
            revert NotPrivileged(vault);
        }
        IERC20(token).safeTransfer(vault, amount);
        emit TokenTransferred(token, vault, amount);
    }

    /**
     * Swap Functions **
     */

    /**
     * @notice Swaps asset for debtToken with fees.
     * @dev This function adds support to fee-on-transfer tokens. The actualTransferAmt is calculated, by recording token balance state before and after the transfer.
     * @param receiver The address that will receive the debtToken tokens.
     * @param assetAmount The amount of asset to be swapped.
     * @return Amount of debtToken minted to the sender.
     */
    // @custom:event Emits AssetForDebtTokenSwapped event.
    function swapIn(
        address asset,
        address receiver,
        uint256 assetAmount
    )
        external
        isActive
        nonReentrant
        returns (uint256)
    {
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(assetAmount);
        _ensureAssetSupported(asset);

        uint256 actualTransferAmt = _getActualTransferAmount(asset, assetAmount);
        // convert to decimal 18
        uint256 actualTransferAmtInUSD = _previewTokenUSDAmount(asset, actualTransferAmt, FeeDirection.IN);

        // calculate feeIn
        uint256 fee = _calculateFee(asset, actualTransferAmtInUSD, FeeDirection.IN);
        uint256 debtTokenToMint = actualTransferAmtInUSD - fee;

        AppStorage.Layout storage s = AppStorage.layout();
        AssetConfig storage assetConfig = s.assetConfigs[asset];
        if (assetConfig.debtTokenMinted + actualTransferAmtInUSD > assetConfig.debtTokenMintCap) {
            revert DebtTokenMintCapReached(
                assetConfig.debtTokenMinted, actualTransferAmtInUSD, assetConfig.debtTokenMintCap
            );
        }

        uint256 today = block.timestamp / 1 days;

        if (today > s.day) {
            s.day = today;
            s.dailyMintCount[asset] = 0;
        }

        uint256 dailyMinted = s.dailyMintCount[asset];
        if (dailyMinted + actualTransferAmtInUSD > assetConfig.dailyDebtTokenMintCap) {
            revert DebtTokenDailyMintCapReached(dailyMinted, actualTransferAmtInUSD, assetConfig.dailyDebtTokenMintCap);
        }

        unchecked {
            assetConfig.debtTokenMinted += actualTransferAmtInUSD;
            s.dailyMintCount[asset] += actualTransferAmtInUSD;
        }

        // mint debtToken to receiver
        s.debtToken.mint(receiver, debtTokenToMint);

        // mint debtToken fee to rewardManager
        if (fee != 0) {
            s.debtToken.mint(address(this), fee);
            s.debtToken.approve(address(s.rewardManager), fee);
            s.rewardManager.increaseSATPerUintStaked(fee);
        }

        emit AssetForDebtTokenSwapped(msg.sender, receiver, asset, actualTransferAmt, debtTokenToMint, fee);
        return debtTokenToMint;
    }

    function _getActualTransferAmount(address asset, uint256 amount) internal returns (uint256) {
        uint256 balanceBefore = IERC20(asset).balanceOf(address(this));
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfter = IERC20(asset).balanceOf(address(this));
        return balanceAfter - balanceBefore;
    }

    /**
     * @notice Schedule a swap debtToken for asset.
     * @param asset The address of the asset.
     * @param amount The amount of debt tokens.
     */
    function scheduleSwapOut(address asset, uint256 amount) external isActive nonReentrant returns (uint256) {
        _ensureNonzeroAmount(amount);
        _ensureAssetSupported(asset);

        AppStorage.Layout storage s = AppStorage.layout();
        uint32 withdrawalTimeCatched = s.withdrawalTime[asset][msg.sender];
        if (withdrawalTimeCatched != 0) {
            revert WithdrawalAlreadyScheduled(withdrawalTimeCatched);
        }

        AssetConfig storage assetConfig = s.assetConfigs[asset];
        uint32 withdrawalTime = uint32(block.timestamp + assetConfig.swapWaitingPeriod);
        s.withdrawalTime[asset][msg.sender] = withdrawalTime;

        uint256 fee = _calculateFee(asset, amount, FeeDirection.OUT);
        uint256 swapAmount = amount - fee;
        uint256 assetAmount = _previewAssetAmountFromDebtToken(asset, swapAmount, FeeDirection.OUT);

        uint256 debtBalance = s.debtToken.balanceOf(msg.sender);
        if (debtBalance < amount) {
            revert NotEnoughDebtToken(debtBalance, amount);
        }

        if (assetConfig.debtTokenMinted < swapAmount) {
            revert DebtTokenMintedUnderflow(assetConfig.debtTokenMinted, swapAmount);
        }

        unchecked {
            assetConfig.debtTokenMinted -= swapAmount;
        }

        if (fee != 0) {
            s.debtToken.sendToXApp(msg.sender, fee);
            s.debtToken.approve(address(s.rewardManager), fee);
            s.rewardManager.increaseSATPerUintStaked(fee);
        }

        s.debtToken.burn(msg.sender, swapAmount);
        s.scheduledWithdrawalAmount[asset][msg.sender] = assetAmount;
        emit WithdrawalScheduled(asset, msg.sender, assetAmount, fee, withdrawalTime);
        return assetAmount;
    }

    /**
     * @dev Withdraw a specific asset after scheduling a swapOut.
     * @param asset The address of the asset to be withdrawn.
     */
    function withdraw(address asset) external {
        AppStorage.Layout storage s = AppStorage.layout();
        uint32 withdrawalTimeCatched = s.withdrawalTime[asset][msg.sender];
        if (withdrawalTimeCatched == 0 || block.timestamp < withdrawalTimeCatched) {
            revert WithdrawalNotAvailable(withdrawalTimeCatched);
        }

        s.withdrawalTime[asset][msg.sender] = 0;

        uint256 _amount = s.scheduledWithdrawalAmount[asset][msg.sender];
        s.scheduledWithdrawalAmount[asset][msg.sender] = 0;

        // check the asset is enough
        uint256 assetAmount = IERC20(asset).balanceOf(address(this));
        if (assetAmount < _amount) {
            revert AssetNotEnough(assetAmount, _amount);
        }

        IERC20(asset).safeTransfer(msg.sender, _amount);
        emit Withdraw(asset, msg.sender, _amount);
    }

    /**
     * @notice Swaps debtToken for a asset.
     * @param receiver The address where the stablecoin will be sent.
     * @param amount The amount of stable tokens to swap.
     * @return The amount of asset received.
     */
    // @custom:event Emits DebtTokenForAssetSwapped event.
    function swapOutPrivileged(
        address asset,
        address receiver,
        uint256 amount
    )
        external
        isActive
        onlyPrivileged
        nonReentrant
        returns (uint256)
    {
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(amount);
        _ensureAssetSupported(asset);

        AppStorage.Layout storage s = AppStorage.layout();

        // get asset amount
        uint256 assetAmount = _previewAssetAmountFromDebtToken(asset, amount, FeeDirection.OUT);

        uint256 debtBalance = s.debtToken.balanceOf(msg.sender);
        if (debtBalance < amount) {
            revert NotEnoughDebtToken(debtBalance, amount);
        }

        AssetConfig storage assetConfig = s.assetConfigs[asset];

        if (assetConfig.debtTokenMinted < amount) {
            revert DebtTokenMintedUnderflow(assetConfig.debtTokenMinted, amount);
        }

        unchecked {
            assetConfig.debtTokenMinted -= amount;
        }

        s.debtToken.burn(msg.sender, amount);
        IERC20(asset).safeTransfer(receiver, assetAmount);
        emit DebtTokenForAssetSwapped(msg.sender, receiver, asset, amount, assetAmount, 0);
        return assetAmount;
    }

    /**
     * @notice Swaps stable tokens for debtToken.
     * @dev This function adds support to fee-on-transfer tokens. The actualTransferAmt is calculated, by recording token balance state before and after the transfer.
     * @param receiver The address that will receive the debtToken tokens.
     * @param assetAmount The amount of stable tokens to be swapped.
     * @return Amount of debtToken minted to the sender.
     */
    // @custom:event Emits AssetForDebtTokenSwapped event.
    function swapInPrivileged(
        address asset,
        address receiver,
        uint256 assetAmount
    )
        external
        isActive
        onlyPrivileged
        nonReentrant
        returns (uint256)
    {
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(assetAmount);
        _ensureAssetSupported(asset);

        AppStorage.Layout storage s = AppStorage.layout();

        // transfer IN, supporting fee-on-transfer tokens
        uint256 balanceBefore = IERC20(asset).balanceOf(address(this));
        IERC20(asset).safeTransferFrom(msg.sender, address(this), assetAmount);
        uint256 balanceAfter = IERC20(asset).balanceOf(address(this));

        // calculate actual transfered amount (in case of fee-on-transfer tokens)
        uint256 actualTransferAmt = balanceAfter - balanceBefore;

        // convert to decimal 18
        uint256 actualTransferAmtInUSD = _previewTokenUSDAmount(asset, actualTransferAmt, FeeDirection.IN);

        AssetConfig storage assetConfig = s.assetConfigs[asset];
        if (assetConfig.debtTokenMinted + actualTransferAmtInUSD > assetConfig.debtTokenMintCap) {
            revert DebtTokenMintCapReached(
                assetConfig.debtTokenMinted, actualTransferAmtInUSD, assetConfig.debtTokenMintCap
            );
        }
        unchecked {
            assetConfig.debtTokenMinted += actualTransferAmtInUSD;
        }

        // mint debtToken to receiver
        s.debtToken.mint(receiver, actualTransferAmtInUSD);

        emit AssetForDebtTokenSwapped(msg.sender, receiver, asset, actualTransferAmt, actualTransferAmtInUSD, 0);
        return actualTransferAmtInUSD;
    }

    /**
     * Admin Functions **
     */

    /**
     * @notice Pause the NYM contract.
     * @dev Reverts if the contract is already paused.
     */
    // @custom:event Emits NYMPaused event.
    function pause() external onlyRole(Config.OWNER_ROLE) {
        AppStorage.Layout storage s = AppStorage.layout();
        if (s.isNymPaused) {
            revert AlreadyPaused();
        }
        s.isNymPaused = true;
        emit NYMPaused(msg.sender);
    }

    /**
     * @notice Resume the NYM contract.
     * @dev Reverts if the contract is not paused.
     */
    // @custom:event Emits NYMResumed event.
    function resume() external onlyRole(Config.OWNER_ROLE) {
        AppStorage.Layout storage s = AppStorage.layout();
        if (!s.isNymPaused) {
            revert NotPaused();
        }
        s.isNymPaused = false;
        emit NYMResumed(msg.sender);
    }

    /**
     * @notice Set the privileged status of an address.
     * @param account The address to set the privileged status.
     * @param isPrivileged_ The privileged status to set.
     */
    function setPrivileged(address account, bool isPrivileged_) external onlyRole(Config.OWNER_ROLE) {
        AppStorage.Layout storage s = AppStorage.layout();
        s.isPrivileged[account] = isPrivileged_;
        emit PrivilegedSet(account, isPrivileged_);
    }

    /**
     * Helper Functions **
     */

    /**
     * @notice Calculates the amount of debtToken that would be burnt from the user.
     * @dev This calculation might be off with a bit, if the price of the oracle for this asset is not updated in the block this function is invoked.
     * @param amount The amount of debt tokens used for swap.
     * @return The amount of asset that would be taken from the user.
     */
    function previewSwapOut(address asset, uint256 amount) external returns (uint256, uint256) {
        _ensureNonzeroAmount(amount);
        _ensureAssetSupported(asset);

        uint256 fee = _calculateFee(asset, amount, FeeDirection.OUT);
        uint256 assetAmount = _previewAssetAmountFromDebtToken(asset, amount - fee, FeeDirection.OUT);

        return (assetAmount, fee);
    }

    /**
     * @notice Calculates the amount of debtToken that would be sent to the receiver.
     * @dev This calculation might be off with a bit, if the price of the oracle for this asset is not updated in the block this function is invoked.
     * @param assetAmount The amount of stable tokens provided for the swap.
     * @return The amount of debtToken that would be sent to the receiver.
     */
    function previewSwapIn(address asset, uint256 assetAmount) external returns (uint256, uint256) {
        _ensureNonzeroAmount(assetAmount);
        _ensureAssetSupported(asset);

        uint256 assetAmountUSD = _previewTokenUSDAmount(asset, assetAmount, FeeDirection.IN);

        //calculate feeIn
        uint256 fee = _calculateFee(asset, assetAmountUSD, FeeDirection.IN);
        uint256 debtTokenToMint = assetAmountUSD - fee;

        return (debtTokenToMint, fee);
    }

    // @notice Converts the given amount of debtToken to asset amount based on the asset's decimals.
    // @param asset The address of the asset.
    // @param amount The amount of debtToken.
    // @return The converted asset amount.
    function convertDebtTokenToAssetAmount(address asset, uint256 amount) public view returns (uint256) {
        uint256 scaledAmt;
        uint256 decimals = IERC20Metadata(asset).decimals();
        if (decimals == Config.TARGET_DIGITS) {
            scaledAmt = amount;
        } else if (decimals < Config.TARGET_DIGITS) {
            scaledAmt = amount / (10 ** (Config.TARGET_DIGITS - decimals));
        } else {
            scaledAmt = amount * (10 ** (decimals - Config.TARGET_DIGITS));
        }

        return scaledAmt;
    }

    /**
     * @notice Converts the given amount of asset to debtToken amount based on the asset's decimals.
     * @param asset The address of the asset.
     * @param amount The amount of asset.
     * @return The converted debtToken amount.
     */
    function convertAssetToDebtTokenAmount(address asset, uint256 amount) public view returns (uint256) {
        uint256 scaledAmt;
        uint256 decimals = IERC20Metadata(asset).decimals();
        if (decimals == Config.TARGET_DIGITS) {
            scaledAmt = amount;
        } else if (decimals < Config.TARGET_DIGITS) {
            scaledAmt = amount * (10 ** (Config.TARGET_DIGITS - decimals));
        } else {
            scaledAmt = amount / (10 ** (decimals - Config.TARGET_DIGITS));
        }

        return scaledAmt;
    }

    /**
     * @dev Calculates the USD value of the given amount of stable tokens depending on the swap direction.
     * @param amount The amount of stable tokens.
     * @return The USD value of the given amount of stable tokens scaled by 1e18 taking into account the direction of the swap
     */
    function _previewTokenUSDAmount(
        address asset,
        uint256 amount,
        FeeDirection direction
    )
        internal
        returns (uint256)
    {
        return (convertAssetToDebtTokenAmount(asset, amount) * _getPriceInUSD(asset, direction)) / Config.MANTISSA_ONE;
    }

    /**
     * @dev Calculate the amount of assets from the given amount of debt tokens.
     * @param asset The address of the asset.
     * @param amount The amount of debt tokens.
     */
    function _previewAssetAmountFromDebtToken(
        address asset,
        uint256 amount,
        FeeDirection direction
    )
        internal
        returns (uint256)
    {
        return (convertDebtTokenToAssetAmount(asset, amount) * Config.MANTISSA_ONE) / _getPriceInUSD(asset, direction);
    }

    /**
     * @notice Get the price of asset in USD.
     * @dev This function gets the price of the asset in USD.
     * @return The price in USD, adjusted based on the selected direction.
     */
    function _getPriceInUSD(address asset, FeeDirection direction) internal returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        AssetConfig storage assetConfig = s.assetConfigs[asset];
        if (!assetConfig.isUsingOracle) {
            return Config.ONE_DOLLAR;
        }

        // get price with decimals 18
        uint256 price = s.assetConfigs[asset].oracle.fetchPrice(IERC20(asset));

        if (price > assetConfig.maxPrice || price < assetConfig.minPrice) {
            revert InvalidPrice(price);
        }

        if (direction == FeeDirection.IN) {
            // MIN(1, price)
            return price < Config.ONE_DOLLAR ? price : Config.ONE_DOLLAR;
        } else {
            // MAX(1, price)
            return price > Config.ONE_DOLLAR ? price : Config.ONE_DOLLAR;
        }
    }

    /**
     * @notice Calculate the fee amount based on the input amount and fee percentage.
     * @dev Reverts if the fee percentage calculation results in rounding down to 0.
     * @param amount The input amount to calculate the fee from.
     * @param direction The direction of the fee: FeeDirection.IN or FeeDirection.OUT.
     * @return The fee amount.
     */
    function _calculateFee(address asset, uint256 amount, FeeDirection direction) internal view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        AssetConfig storage assetConfig = s.assetConfigs[asset];
        uint256 feePercent;
        if (direction == FeeDirection.IN) {
            feePercent = assetConfig.feeIn;
        } else {
            feePercent = assetConfig.feeOut;
        }
        if (feePercent == 0) {
            return 0;
        } else {
            uint256 feeAmount = amount * feePercent;
            // checking if the percent calculation will result in rounding down to 0
            if (feeAmount < Config.BASIS_POINTS_DIVISOR) {
                revert AmountTooSmall(feeAmount);
            }
            return (feeAmount) / Config.BASIS_POINTS_DIVISOR;
        }
    }

    /**
     * @notice Checks that the address is not the zero address.
     * @param someone The address to check.
     */
    function _ensureNonzeroAddress(address someone) private pure {
        if (someone == address(0)) revert ZeroAddress();
    }

    /**
     * @notice Checks that the amount passed as stable tokens is bigger than zero
     * @param amount The amount to validate
     */
    function _ensureNonzeroAmount(uint256 amount) private pure {
        if (amount == 0) revert ZeroAmount();
    }

    /**
     * @notice Ensures that the given asset is supported.
     * @param asset The address of the asset.
     */
    function _ensureAssetSupported(address asset) private view {
        AppStorage.Layout storage s = AppStorage.layout();
        if (!s.isAssetSupported[asset]) {
            revert AssetNotSupported(asset);
        }
    }

    /* Getters */

    // @notice Get the oracle for the given asset.
    function oracle(address asset) public view returns (IPriceFeedAggregatorFacet) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[asset].oracle;
    }

    // @notice Get the feeIn for the given asset.
    function feeIn(address asset) public view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[asset].feeIn;
    }

    // @notice Get the feeOut for the given asset.
    function feeOut(address asset) public view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[asset].feeOut;
    }

    // @notice Get the debt token mint cap for the given asset.
    function debtTokenMintCap(address asset) public view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[asset].debtTokenMintCap;
    }

    // @notice Get the daily debt token mint cap for the given asset.
    function dailyDebtTokenMintCap(address asset) public view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[asset].dailyDebtTokenMintCap;
    }

    // @notice Get the debt token minted amount for the given asset.
    function debtTokenMinted(address asset) public view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[asset].debtTokenMinted;
    }

    // @notice Check if the given asset is using an oracle.
    function isUsingOracle(address asset) public view returns (bool) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[asset].isUsingOracle;
    }

    // @notice Get the swap waiting period for the given asset.
    function swapWaitingPeriod(address asset) public view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[asset].swapWaitingPeriod;
    }

    // @notice Get the remaining daily debt token mint cap for the given asset.
    function debtTokenDailyMintCapRemain(address asset) external view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        uint256 today = block.timestamp / 1 days;
        uint256 currentDailyMintCount;
        if (today > s.day) {
            currentDailyMintCount = 0; // If it's a new day and no swapIn has occurred yet, current count is 0
        } else {
            currentDailyMintCount = s.dailyMintCount[asset];
        }
        return s.assetConfigs[asset].dailyDebtTokenMintCap - currentDailyMintCount;
    }

    function dailyMintCount(address asset) external view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        uint256 today = block.timestamp / 1 days;
        if (today > s.day) {
            return 0; // If it's a new day and no swapIn has occurred yet, return 0
        }
        return s.dailyMintCount[asset];
    }

    // @notice Get the pending withdrawal amount and time for the given asset and account.
    function pendingWithdrawal(address asset, address account) external view returns (uint256, uint32) {
        AppStorage.Layout storage s = AppStorage.layout();
        return (s.scheduledWithdrawalAmount[asset][account], s.withdrawalTime[asset][account]);
    }

    // @notice Get the pending withdrawals for the given assets and account.
    function pendingWithdrawals(
        address[] memory assets,
        address account
    )
        external
        view
        returns (uint256[] memory, uint32[] memory)
    {
        AppStorage.Layout storage s = AppStorage.layout();
        uint256[] memory amounts = new uint256[](assets.length);
        uint32[] memory times = new uint32[](assets.length);
        for (uint256 i; i < assets.length; ++i) {
            amounts[i] = s.scheduledWithdrawalAmount[assets[i]][account];
            times[i] = s.withdrawalTime[assets[i]][account];
        }

        return (amounts, times);
    }

    function isNymPaused() external view returns (bool) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.isNymPaused;
    }

    function isAssetSupported(address asset) external view returns (bool) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.isAssetSupported[asset];
    }
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.19;

import {AccessControlInternal} from "@solidstate/contracts/access/access_control/AccessControlInternal.sol";
import {OwnableInternal} from "@solidstate/contracts/access/ownable/OwnableInternal.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {INexusYieldManagerFacet, AssetConfig, ChainConfig} from "../interfaces/INexusYieldManagerFacet.sol";
import {IPriceFeedAggregatorFacet} from "../interfaces/IPriceFeedAggregatorFacet.sol";
import {IRollupMinter} from "../interfaces/IRollupMinter.sol";
import {IRollupNYM} from "../interfaces/IRollupNYM.sol";
import {AppStorage} from "../AppStorage.sol";
import {Config} from "../Config.sol";
import {XTypes} from "lib/omni/contracts/core/src/libraries/XTypes.sol";

/**
 * @title Nexus Yield Manager Contract.
 * Mutated from:
 * https://github.com/VenusProtocol/venus-protocol/blob/develop/contracts/PegStability/PegStability.sol
 * @notice Contract for swapping stable token for debtToken token and vice versa to maintain the peg stability between them.
 */
contract NexusYieldManagerFacet is INexusYieldManagerFacet, AccessControlInternal, OwnableInternal {
    using SafeERC20 for IERC20;

    modifier onlyRouter() {
        AppStorage.Layout storage s = AppStorage.layout();
        require(msg.sender == address(s.xAppRouter), "NexusYieldManager: caller is not the router");
        _;
    }

    modifier xrecv(XTypes.MsgShort calldata xmsg) {
        AppStorage.Layout storage s = AppStorage.layout();
        s.xmsg = xmsg;
        _;
        delete s.xmsg;
    }

    /**
     * @dev Prevents functions to execute when contract is paused.
     */
    modifier isActive() {
        AppStorage.Layout storage s = AppStorage.layout();
        if (s.isPaused) revert Paused();
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

    function setChainConfig(
        uint64 chainID_,
        address debtToken_,
        address rollupMinter_,
        address nexusYield_,
        address feeReceiver_,
        uint64 mintGas_,
        uint64 burnGas_
    ) external {
        AppStorage.Layout storage s = AppStorage.layout();
        ChainConfig storage chainConfig = s.chainConfigs[chainID_];
        chainConfig.debtToken = debtToken_;
        chainConfig.rollupMinter = rollupMinter_;
        chainConfig.nexusYieldManager = nexusYield_;
        chainConfig.feeReceiver = feeReceiver_;
        chainConfig.mintGas = mintGas_;
        chainConfig.burnGas = burnGas_;
    }

    function setAssetConfig(uint64 chain, address asset, AssetConfig calldata assetConfig_) external {
        AppStorage.Layout storage s = AppStorage.layout();
        if (assetConfig_.feeIn >= Config.BASIS_POINTS_DIVISOR || assetConfig_.feeOut >= Config.BASIS_POINTS_DIVISOR) {
            revert InvalidFee(assetConfig_.feeIn, assetConfig_.feeOut);
        }
        AssetConfig storage assetConfig = s.assetConfigs[chain][asset];
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
        s.isAssetSupported[chain][asset] = true;

        emit AssetConfigSetting(chain, asset, assetConfig_);
    }

    /**
     * @notice Removes support for an asset and marks it as sunset.
     * @param asset The address of the asset to sunset.
     */
    function sunsetAsset(uint64 chain, address asset) external {
        AppStorage.Layout storage s = AppStorage.layout();
        s.isAssetSupported[chain][asset] = false;

        emit AssetSunset(asset);
    }

    /**
     * Swap Functions **
     */

    /**
     * @notice Swaps asset for debtToken with fees.
     * @dev This function adds support to fee-on-transfer tokens. The actualTransferAmt is calculated, by recording token balance state before and after the transfer.
     * @param receiver The address that will receive the debtToken tokens.
     * @param actualTransferAmt The amount of asset to be swapped.
     */
    // @custom:event Emits AssetForDebtTokenSwapped event.
    function swapIn(
        address asset,
        address receiver,
        uint256 actualTransferAmt,
        uint64 destChainId,
        uint256 price,
        XTypes.MsgShort calldata xmsg
    ) external isActive onlyRouter xrecv(xmsg) {
        AppStorage.Layout storage s = AppStorage.layout();
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(actualTransferAmt);
        _ensureAssetSupported(destChainId, asset);
        _ensureSourceChainSenderVaild();

        _updateAssetPrice(xmsg.sourceChainId, asset, price);

        uint256 actualTransferAmtInUSD = _previewTokenUSDAmount(asset, actualTransferAmt, FeeDirection.IN);

        _checkDebtTokenMintCap(s, xmsg.sourceChainId, asset, actualTransferAmtInUSD);
        _updateDailyMintCount(s, xmsg.sourceChainId, asset, actualTransferAmtInUSD);
        _swapInMintDebtToken(s, destChainId, asset, receiver, actualTransferAmtInUSD);
    }

    /**
     * @notice Schedule a swap debtToken for asset.
     * @param asset The address of the asset.
     * @param amount The amount of debt tokens.
     */
    function scheduleSwapOut(
        address account,
        address asset,
        uint256 amount,
        uint256 price,
        XTypes.MsgShort calldata xmsg
    ) external isActive onlyRouter xrecv(xmsg) {
        AppStorage.Layout storage s = AppStorage.layout();
        uint64 sourceChainId = xmsg.sourceChainId;

        _ensureNonzeroAmount(amount);
        _ensureAssetSupported(sourceChainId, asset);
        _ensureSourceChainSenderVaild();
        _checkWithdrawalTimeNonZero(sourceChainId, asset, account);
        _updateAssetPrice(sourceChainId, asset, price);
        _scheduleSwapOut(s, sourceChainId, asset, account, amount);
    }

    function _scheduleSwapOut(
        AppStorage.Layout storage s,
        uint64 sourceChainId,
        address asset,
        address account,
        uint256 amount
    ) private {
        AssetConfig storage assetConfig = s.assetConfigs[sourceChainId][asset];

        s.withdrawalTime[sourceChainId][asset][account] = uint32(block.timestamp + assetConfig.swapWaitingPeriod);

        uint256 fee = _calculateFee(asset, amount, FeeDirection.OUT);
        uint256 swapAmount = amount - fee;
        uint256 assetAmount = _previewAssetAmountFromDebtToken(asset, swapAmount, FeeDirection.OUT);

        if (assetConfig.debtTokenMinted < swapAmount) {
            revert DebtTokenMintedUnderflow(assetConfig.debtTokenMinted, swapAmount);
        }

        unchecked {
            assetConfig.debtTokenMinted -= swapAmount;
        }

        _burnOnSourceChain(account, amount, fee);

        s.scheduledWithdrawalAmount[sourceChainId][asset][account] = assetAmount;
        emit WithdrawalScheduled(asset, account, assetAmount, fee, s.withdrawalTime[sourceChainId][asset][account]);
    }

    /**
     * @dev Withdraw a specific asset after scheduling a swapOut.
     * @param asset The address of the asset to be withdrawn.
     */
    function withdraw(address account, address asset, uint256 amount, XTypes.MsgShort calldata xmsg)
        external
        onlyRouter
        xrecv(xmsg)
    {
        AppStorage.Layout storage s = AppStorage.layout();
        _ensureSourceChainSenderVaild();

        _checkWithdrawalTimeValid(xmsg.sourceChainId, asset, account);

        s.withdrawalTime[xmsg.sourceChainId][asset][account] = 0;
        uint256 _amount = s.scheduledWithdrawalAmount[xmsg.sourceChainId][asset][account];
        require(_amount == amount, "NexusYieldManager: amount mismatch");
        s.scheduledWithdrawalAmount[xmsg.sourceChainId][asset][account] = 0;

        ChainConfig storage chain = s.chainConfigs[xmsg.sourceChainId];
        bytes memory data = abi.encodeWithSelector(IRollupNYM.transferAsset.selector, asset, account, _amount);
        s.xAppRouter.callToPortal(xmsg.sourceChainId, chain.nexusYieldManager, data, 2000000);

        emit Withdraw(asset, account, _amount);
    }

    /**
     * Admin Functions **
     */

    /**
     * @notice Pause the NYM contract.
     * @dev Reverts if the contract is already paused.
     */
    // @custom:event Emits NYMPaused event.
    function pause() external {
        AppStorage.Layout storage s = AppStorage.layout();
        if (s.isPaused) {
            revert AlreadyPaused();
        }
        s.isPaused = true;
        emit NYMPaused(msg.sender);
    }

    /**
     * @notice Resume the NYM contract.
     * @dev Reverts if the contract is not paused.
     */
    // @custom:event Emits NYMResumed event.
    function resume() external {
        AppStorage.Layout storage s = AppStorage.layout();
        if (!s.isPaused) {
            revert NotPaused();
        }
        s.isPaused = false;
        emit NYMResumed(msg.sender);
    }

    /**
     * @notice Set the address of the Reward Manager.
     * @param rewardManager_ The address of the Reward Manager.
     */
    function setRewardManager(address rewardManager_) external {
        AppStorage.Layout storage s = AppStorage.layout();
        address oldTreasuryAddress = s.rewardManagerAddr;
        s.rewardManagerAddr = rewardManager_;
        emit RewardManagerChanged(oldTreasuryAddress, rewardManager_);
    }

    /**
     * @notice Set the privileged status of an address.
     * @param account The address to set the privileged status.
     * @param isPrivileged_ The privileged status to set.
     */
    function setPrivileged(address account, bool isPrivileged_) external {
        AppStorage.Layout storage s = AppStorage.layout();
        s.isPrivileged[account] = isPrivileged_;
        emit PrivilegedSet(account, isPrivileged_);
    }

    function addChainContract(uint64 chainId, address contractAddress) external {
        AppStorage.Layout storage s = AppStorage.layout();
        s.contractOn[chainId] = contractAddress;
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
    function previewSwapOut(address asset, uint256 amount) external view returns (uint256, uint256) {
        _ensureNonzeroAmount(amount);
        // _ensureAssetSupported(asset);

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
    function previewSwapIn(address asset, uint256 assetAmount) external view returns (uint256, uint256) {
        _ensureNonzeroAmount(assetAmount);
        // _ensureAssetSupported(asset);

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
        AppStorage.Layout storage s = AppStorage.layout();
        uint256 scaledAmt;
        uint256 decimals = s.assetConfigs[s.xmsg.sourceChainId][asset].decimals;
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
        AppStorage.Layout storage s = AppStorage.layout();
        uint256 scaledAmt;
        uint256 decimals = s.assetConfigs[s.xmsg.sourceChainId][asset].decimals;
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
    function _previewTokenUSDAmount(address asset, uint256 amount, FeeDirection direction)
        internal
        view
        returns (uint256)
    {
        return (convertAssetToDebtTokenAmount(asset, amount) * _getPriceInUSD(asset, direction)) / Config.MANTISSA_ONE;
    }

    /**
     * @dev Calculate the amount of assets from the given amount of debt tokens.
     * @param asset The address of the asset.
     * @param amount The amount of debt tokens.
     */
    function _previewAssetAmountFromDebtToken(address asset, uint256 amount, FeeDirection direction)
        internal
        view
        returns (uint256)
    {
        return (convertDebtTokenToAssetAmount(asset, amount) * Config.MANTISSA_ONE) / _getPriceInUSD(asset, direction);
    }

    /**
     * @notice Get the price of asset in USD.
     * @dev This function gets the price of the asset in USD.
     * @return The price in USD, adjusted based on the selected direction.
     */
    function _getPriceInUSD(address asset, FeeDirection direction) internal view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        AssetConfig storage assetConfig = s.assetConfigs[s.xmsg.sourceChainId][asset];
        if (!assetConfig.isUsingOracle) {
            return Config.ONE_DOLLAR;
        }

        // get price with decimals 18
        uint256 price = s.assetPrice[s.xmsg.sourceChainId][asset];

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
        AssetConfig storage assetConfig = s.assetConfigs[s.xmsg.sourceChainId][asset];
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
    function _ensureAssetSupported(uint64 chainId, address asset) private view {
        AppStorage.Layout storage s = AppStorage.layout();
        if (!s.isAssetSupported[chainId][asset]) {
            revert AssetNotSupported(chainId, asset);
        }
    }

    function _ensureSourceChainSenderVaild() private view {
        AppStorage.Layout storage s = AppStorage.layout();
        if (s.xmsg.sender != s.contractOn[s.xmsg.sourceChainId]) {
            revert InvalidSourceChainSender(s.xmsg.sender, s.contractOn[s.xmsg.sourceChainId]);
        }
    }

    function _ensureChainIdSupported(uint64 chainId) private view {
        AppStorage.Layout storage s = AppStorage.layout();
        if (!s.supportedChainIds[chainId]) revert InvalidChainId();
    }

    /* Getters */

    // @notice Get the oracle for the given asset.
    function oracle(uint64 chainID, address asset) public view returns (IPriceFeedAggregatorFacet) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[chainID][asset].oracle;
    }

    // @notice Get the feeIn for the given asset.
    function feeIn(uint64 chainID, address asset) public view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[chainID][asset].feeIn;
    }

    // @notice Get the feeOut for the given asset.
    function feeOut(uint64 chainID, address asset) public view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[chainID][asset].feeOut;
    }

    // @notice Get the debt token mint cap for the given asset.
    function debtTokenMintCap(uint64 chainID, address asset) public view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[chainID][asset].debtTokenMintCap;
    }

    // @notice Get the daily debt token mint cap for the given asset.
    function dailyDebtTokenMintCap(uint64 chainID, address asset) public view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[chainID][asset].dailyDebtTokenMintCap;
    }

    // @notice Get the debt token minted amount for the given asset.
    function debtTokenMinted(uint64 chainID, address asset) public view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[chainID][asset].debtTokenMinted;
    }

    // @notice Check if the given asset is using an oracle.
    function isUsingOracle(uint64 chainID, address asset) public view returns (bool) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[chainID][asset].isUsingOracle;
    }

    // @notice Get the swap waiting period for the given asset.
    function swapWaitingPeriod(uint64 chainID, address asset) public view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[chainID][asset].swapWaitingPeriod;
    }

    // @notice Get the remaining daily debt token mint cap for the given asset.
    function debtTokenDailyMintCapRemain(uint64 chainID, address asset) external view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.assetConfigs[chainID][asset].dailyDebtTokenMintCap - s.dailyMintCount[chainID][asset];
    }

    // @notice Get the pending withdrawal amount and time for the given asset and account.
    function pendingWithdrawal(uint64 chainId, address asset, address account)
        external
        view
        returns (uint256, uint32)
    {
        AppStorage.Layout storage s = AppStorage.layout();
        return (s.scheduledWithdrawalAmount[chainId][asset][account], s.withdrawalTime[chainId][asset][account]);
    }

    // @notice Get the pending withdrawals for the given assets and account.
    function pendingWithdrawals(uint64[] memory chainId, address[] memory assets, address account)
        external
        view
        returns (uint256[] memory, uint32[] memory)
    {
        AppStorage.Layout storage s = AppStorage.layout();
        uint256[] memory amounts = new uint256[](assets.length);
        uint32[] memory times = new uint32[](assets.length);
        for (uint256 i; i < assets.length; ++i) {
            amounts[i] = s.scheduledWithdrawalAmount[chainId[i]][assets[i]][account];
            times[i] = s.withdrawalTime[chainId[i]][assets[i]][account];
        }

        return (amounts, times);
    }

    function _mintOnDestChain(uint64 destChainId, address account, uint256 amount, uint64 fee) internal {
        AppStorage.Layout storage s = AppStorage.layout();
        ChainConfig storage chain = s.chainConfigs[destChainId];
        bytes memory data = abi.encodeWithSelector(IRollupMinter.mint.selector, account, amount);
        s.xAppRouter.callToPortal(destChainId, chain.rollupMinter, data, chain.mintGas);

        if (fee != 0) {
            data = abi.encodeWithSelector(IRollupMinter.mint.selector, chain.feeReceiver, fee);
            s.xAppRouter.callToPortal(s.xmsg.sourceChainId, chain.rollupMinter, data, chain.mintGas);
        }
    }

    function _swapInMintDebtToken(
        AppStorage.Layout storage s,
        uint64 destChainId,
        address asset,
        address receiver,
        uint256 actualTransferAmtInUSD
    ) private {
        uint256 fee = _calculateFee(asset, actualTransferAmtInUSD, FeeDirection.IN);
        uint256 debtTokenToMint = actualTransferAmtInUSD - fee;

        ChainConfig storage chain = s.chainConfigs[destChainId];
        bytes memory data = abi.encodeWithSelector(IRollupMinter.mint.selector, receiver, debtTokenToMint);
        s.xAppRouter.callToPortal(destChainId, chain.rollupMinter, data, chain.mintGas);

        if (fee != 0) {
            data = abi.encodeWithSelector(IRollupMinter.mint.selector, chain.feeReceiver, fee);
            s.xAppRouter.callToPortal(destChainId, chain.rollupMinter, data, chain.mintGas);
        }
    }

    function _burnOnSourceChain(address account, uint256 amount, uint256 fee) internal {
        AppStorage.Layout storage s = AppStorage.layout();
        uint64 sourceChainId = s.xmsg.sourceChainId;
        ChainConfig storage chain = s.chainConfigs[sourceChainId];

        bytes memory data = abi.encodeWithSelector(IRollupMinter.burn.selector, account, amount);
        s.xAppRouter.callToPortal(sourceChainId, chain.rollupMinter, data, chain.burnGas);

        if (fee != 0) {
            data = abi.encodeWithSelector(IRollupMinter.mint.selector, chain.feeReceiver, fee);
            s.xAppRouter.callToPortal(sourceChainId, chain.rollupMinter, data, chain.mintGas);
        }
    }

    function _checkWithdrawalTimeNonZero(uint64 sourceChainId, address asset, address account) internal view {
        AppStorage.Layout storage s = AppStorage.layout();
        uint32 withdrawalTimeCatched = s.withdrawalTime[sourceChainId][asset][account];
        if (withdrawalTimeCatched != 0) {
            revert WithdrawalAlreadyScheduled(withdrawalTimeCatched);
        }
    }

    function _checkWithdrawalTimeValid(uint64 sourceChainId, address asset, address account) internal view {
        AppStorage.Layout storage s = AppStorage.layout();
        uint32 withdrawalTimeCatched = s.withdrawalTime[sourceChainId][asset][account];
        if (withdrawalTimeCatched == 0 || block.timestamp < withdrawalTimeCatched) {
            revert WithdrawalNotAvailable(withdrawalTimeCatched);
        }
    }

    function _updateAssetPrice(uint64 sourceChainId, address asset, uint256 price) private {
        AppStorage.Layout storage s = AppStorage.layout();
        s.assetPrice[sourceChainId][asset] = price;
    }

    function _checkDebtTokenMintCap(
        AppStorage.Layout storage s,
        uint64 sourceChainId,
        address asset,
        uint256 actualTransferAmtInUSD
    ) private view {
        AssetConfig storage assetConfig = s.assetConfigs[sourceChainId][asset];
        if (assetConfig.debtTokenMinted + actualTransferAmtInUSD > assetConfig.debtTokenMintCap) {
            revert DebtTokenMintCapReached(
                assetConfig.debtTokenMinted, actualTransferAmtInUSD, assetConfig.debtTokenMintCap
            );
        }
    }

    function _updateDailyMintCount(
        AppStorage.Layout storage s,
        uint64 sourceChainId,
        address asset,
        uint256 actualTransferAmtInUSD
    ) private {
        uint256 today = block.timestamp / 1 days;

        if (today > s.day) {
            s.day = today;
            s.dailyMintCount[sourceChainId][asset] = 0;
        }

        uint256 dailyMinted = s.dailyMintCount[sourceChainId][asset];
        AssetConfig storage assetConfig = s.assetConfigs[sourceChainId][asset];
        if (dailyMinted + actualTransferAmtInUSD > assetConfig.dailyDebtTokenMintCap) {
            revert DebtTokenDailyMintCapReached(dailyMinted, actualTransferAmtInUSD, assetConfig.dailyDebtTokenMintCap);
        }

        unchecked {
            assetConfig.debtTokenMinted += actualTransferAmtInUSD;
            s.dailyMintCount[sourceChainId][asset] += actualTransferAmtInUSD;
        }
    }

    receive() external payable {}
}

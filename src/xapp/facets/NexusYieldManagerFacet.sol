// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {INexusYieldManager, AssetConfig, ChainConfig} from "../interfaces/INexusYieldManager.sol";
import {IPriceFeedAggregatorFacet} from "../interfaces/IPriceFeedAggregatorFacet.sol";
import {IRollupMinter} from "../interfaces/IRollupMinter.sol";
import {IRollupNYM} from "../interfaces/IRollupNYM.sol";
import {AppStorage} from "../AppStorage.sol";
import {Config} from "../Config.sol";

/**
 * @title Nexus Yield Manager Contract.
 * Mutated from:
 * https://github.com/VenusProtocol/venus-protocol/blob/develop/contracts/PegStability/PegStability.sol
 * @notice Contract for swapping stable token for debtToken token and vice versa to maintain the peg stability between them.
 */
contract NexusYieldManager is INexusYieldManager {
    using SafeERC20 for IERC20;

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

    /**
     * @notice Sets the configuration for an asset.
     * @param asset The address of the asset.
     * @param feeIn_ The fee for swapIn.
     * @param feeOut_ The fee for swapOut.
     * @param debtTokenMintCap_ The maximum amount of debtToken that can be minted for the asset.
     * @param dailyDebtTokenMintCap_ The maximum amount of debtToken that can be minted daily for the asset.
     * @param oracle_ The address of the price feed oracle for the asset.
     * @param isUsingOracle_ A flag indicating whether the asset is using an oracle for price feed.
     * @param swapWaitingPeriod_ The waiting period in seconds before withdrawing the asset after a swap out.
     * @param maxPrice_ The maximum price in USD with decimals 18 for the asset.
     * @param minPrice_ The minimum price in USD with decimals 18 for the asset.
     */
    function setAssetConfig(
        uint64 chain,
        address asset,
        uint256 decimals_,
        uint256 feeIn_,
        uint256 feeOut_,
        uint256 debtTokenMintCap_,
        uint256 dailyDebtTokenMintCap_,
        address oracle_,
        bool isUsingOracle_,
        uint256 swapWaitingPeriod_,
        uint256 maxPrice_,
        uint256 minPrice_
    ) external {
        AppStorage.Layout storage s = AppStorage.layout();
        if (feeIn_ >= Config.BASIS_POINTS_DIVISOR || feeOut_ >= Config.BASIS_POINTS_DIVISOR) {
            revert InvalidFee(feeIn_, feeOut_);
        }
        AssetConfig storage assetConfig = s.assetConfigs[chain][asset];
        assetConfig.decimals = decimals_;
        assetConfig.feeIn = feeIn_;
        assetConfig.feeOut = feeOut_;
        assetConfig.debtTokenMintCap = debtTokenMintCap_;
        assetConfig.dailyDebtTokenMintCap = dailyDebtTokenMintCap_;
        assetConfig.oracle = IPriceFeedAggregatorFacet(oracle_);
        assetConfig.isUsingOracle = isUsingOracle_;
        assetConfig.swapWaitingPeriod = swapWaitingPeriod_;
        assetConfig.maxPrice = maxPrice_;
        assetConfig.minPrice = minPrice_;
        s.isAssetSupported[chain][asset] = true;

        emit AssetConfigSetting(
            chain,
            asset,
            decimals_,
            feeIn_,
            feeOut_,
            debtTokenMintCap_,
            dailyDebtTokenMintCap_,
            oracle_,
            isUsingOracle_,
            swapWaitingPeriod_,
            maxPrice_,
            minPrice_
        );
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
    function swapIn(address asset, address receiver, uint256 actualTransferAmt, uint64 destChainId, uint256 price)
        external
        isActive
    {
        AppStorage.Layout storage s = AppStorage.layout();
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(actualTransferAmt);
        _ensureAssetSupported(destChainId, asset);
        _ensureSourceChainSenderVaild();

        s.assetPrice[xmsg.sourceChainId][asset] = price;

        // convert to decimal 18
        uint256 actualTransferAmtInUSD = _previewTokenUSDAmount(asset, actualTransferAmt, FeeDirection.IN);

        // calculate feeIn
        uint256 fee = _calculateFee(asset, actualTransferAmtInUSD, FeeDirection.IN);
        uint256 debtTokenToMint = actualTransferAmtInUSD - fee;

        AssetConfig storage assetConfig = s.assetConfigs[xmsg.sourceChainId][asset];
        if (assetConfig.debtTokenMinted + actualTransferAmtInUSD > assetConfig.debtTokenMintCap) {
            revert DebtTokenMintCapReached(
                assetConfig.debtTokenMinted, actualTransferAmtInUSD, assetConfig.debtTokenMintCap
            );
        }

        uint256 today = block.timestamp / 1 days;

        if (today > s.day) {
            s.day = today;
            s.dailyMintCount[xmsg.sourceChainId][asset] = 0;
        }

        uint256 dailyMinted = s.dailyMintCount[xmsg.sourceChainId][asset];
        if (dailyMinted + actualTransferAmtInUSD > assetConfig.dailyDebtTokenMintCap) {
            revert DebtTokenDailyMintCapReached(dailyMinted, actualTransferAmtInUSD, assetConfig.dailyDebtTokenMintCap);
        }

        unchecked {
            assetConfig.debtTokenMinted += actualTransferAmtInUSD;
            s.dailyMintCount[xmsg.sourceChainId][asset] += actualTransferAmtInUSD;
        }

        ChainConfig storage chain = s.chainConfigs[destChainId];
        bytes memory data = abi.encodeWithSelector(IRollupMinter.mint.selector, receiver, debtTokenToMint);
        xcall(destChainId, chain.rollupMinter, data, chain.mintGas);

        // mint fee
        if (fee != 0) {
            data = abi.encodeWithSelector(IRollupMinter.mint.selector, chain.feeReceiver, fee);
            xcall(destChainId, chain.rollupMinter, data, chain.mintGas);
        }

        emit AssetForDebtTokenSwapped(msg.sender, receiver, asset, actualTransferAmt, debtTokenToMint, fee);
    }

    /**
     * @notice Schedule a swap debtToken for asset.
     * @param asset The address of the asset.
     * @param amount The amount of debt tokens.
     */
    function scheduleSwapOut(address account, address asset, uint256 amount, uint256 price) external isActive {
        AppStorage.Layout storage s = AppStorage.layout();
        uint64 sourceChainId = xmsg.sourceChainId;

        _ensureNonzeroAmount(amount);
        _ensureAssetSupported(sourceChainId, asset);
        _ensureSourceChainSenderVaild();

        s.assetPrice[sourceChainId][asset] = price;

        uint32 withdrawalTimeCatched = s.withdrawalTime[sourceChainId][asset][account];
        if (withdrawalTimeCatched != 0) {
            revert WithdrawalAlreadyScheduled(withdrawalTimeCatched);
        }

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

        // xcall
        _burnOnSourceChain(account, amount, fee);

        s.scheduledWithdrawalAmount[sourceChainId][asset][account] = assetAmount;
        // emit WithdrawalScheduled(asset, account, assetAmount, fee, withdrawalTime[sourceChainId][asset][account]);
    }

    /**
     * @dev Withdraw a specific asset after scheduling a swapOut.
     * @param asset The address of the asset to be withdrawn.
     */
    function withdraw(address account, address asset, uint256 amount) external {
        AppStorage.Layout storage s = AppStorage.layout();
        _ensureSourceChainSenderVaild();

        uint32 withdrawalTimeCatched = s.withdrawalTime[xmsg.sourceChainId][asset][account];
        if (withdrawalTimeCatched == 0 || block.timestamp < withdrawalTimeCatched) {
            revert WithdrawalNotAvailable(withdrawalTimeCatched);
        }

        s.withdrawalTime[xmsg.sourceChainId][asset][account] = 0;
        uint256 _amount = s.scheduledWithdrawalAmount[xmsg.sourceChainId][asset][account];
        require(_amount == amount, "NexusYieldManager: amount mismatch");
        s.scheduledWithdrawalAmount[xmsg.sourceChainId][asset][account] = 0;

        ChainConfig storage chain = s.chainConfigs[xmsg.sourceChainId];
        bytes memory data = abi.encodeWithSelector(IRollupNYM.transferAsset.selector, asset, account, _amount);
        xcall(xmsg.sourceChainId, chain.nexusYieldManager, data, 2000000);

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
    function previewSwapOut(address asset, uint256 amount) external returns (uint256, uint256) {
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
    function previewSwapIn(address asset, uint256 assetAmount) external returns (uint256, uint256) {
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
        uint256 decimals = s.assetConfigs[xmsg.sourceChainId][asset].decimals;
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
        uint256 decimals = s.assetConfigs[xmsg.sourceChainId][asset].decimals;
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
    function _previewTokenUSDAmount(address asset, uint256 amount, FeeDirection direction) internal returns (uint256) {
        return (convertAssetToDebtTokenAmount(asset, amount) * _getPriceInUSD(asset, direction)) / Config.MANTISSA_ONE;
    }

    /**
     * @dev Calculate the amount of assets from the given amount of debt tokens.
     * @param asset The address of the asset.
     * @param amount The amount of debt tokens.
     */
    function _previewAssetAmountFromDebtToken(address asset, uint256 amount, FeeDirection direction)
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
        AssetConfig storage assetConfig = s.assetConfigs[xmsg.sourceChainId][asset];
        if (!assetConfig.isUsingOracle) {
            return Config.ONE_DOLLAR;
        }

        // get price with decimals 18
        uint256 price = s.assetPrice[xmsg.sourceChainId][asset];

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
        AssetConfig storage assetConfig = s.assetConfigs[xmsg.sourceChainId][asset];
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
        if (xmsg.sender != s.contractOn[xmsg.sourceChainId]) {
            revert InvalidSourceChainSender(xmsg.sender, s.contractOn[xmsg.sourceChainId]);
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
        xcall(destChainId, chain.rollupMinter, data, chain.mintGas);

        if (fee != 0) {
            data = abi.encodeWithSelector(IRollupMinter.mint.selector, chain.feeReceiver, fee);
            xcall(xmsg.sourceChainId, chain.rollupMinter, data, chain.mintGas);
        }
    }

    function _burnOnSourceChain(address account, uint256 amount, uint256 fee) internal {
        AppStorage.Layout storage s = AppStorage.layout();
        uint64 sourceChainId = xmsg.sourceChainId;
        ChainConfig storage chain = s.chainConfigs[sourceChainId];

        bytes memory data = abi.encodeWithSelector(IRollupMinter.burn.selector, account, amount);
        xcall(sourceChainId, chain.rollupMinter, data, chain.burnGas);

        if (fee != 0) {
            data = abi.encodeWithSelector(IRollupMinter.mint.selector, chain.feeReceiver, fee);
            xcall(sourceChainId, chain.rollupMinter, data, chain.mintGas);
        }
    }

    receive() external payable {}
}

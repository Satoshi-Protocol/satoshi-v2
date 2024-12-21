pragma solidity ^0.8.19;

import {IDebtToken} from "./IDebtToken.sol";
import {IPriceFeedAggregatorFacet} from "./IPriceFeedAggregatorFacet.sol";

struct AssetConfig {
    /// The address of ResilientOracle contract wrapped in its interface.
    IPriceFeedAggregatorFacet oracle;
    /// The incoming stableCoin fee. (Fee for swapIn).
    uint256 feeIn;
    /// The outgoing stableCoin fee. (Fee for swapOut).
    uint256 feeOut;
    /// The maximum amount of debtToken that can be minted through this contract.
    uint256 debtTokenMintCap;
    /// The maximum amount of debtToken that can be minted everyday.
    uint256 dailyDebtTokenMintCap;
    /// The total amount of debtToken minted through this asset.
    uint256 debtTokenMinted;
    /// A flag indicating whether the contract is using an oracle or not.
    bool isUsingOracle;
    /// The time used to wait after schedule the withdrawal.
    uint256 swapWaitingPeriod;
    /// The maximum price of the asset. If the price of the asset exceeds this value, the operation will revert.
    uint256 maxPrice;
    /// The minimum price of the asset. If the price of the asset is less than this value, the operation will revert.
    uint256 minPrice;
    /// decimals of the asset
    uint256 decimals;
}

struct ChainConfig {
    address debtToken;
    address rollupMinter;
    address nexusYieldManager;
    address feeReceiver;
    uint64 mintGas;
    uint64 burnGas;
}

interface INexusYieldManagerFacet {
    // Helper enum for calculation of the fee.
    enum FeeDirection {
        IN,
        OUT
    }

    /// @notice Event emitted when contract is paused.
    event NYMPaused(address indexed admin);

    /// @notice Event emitted when the contract is resumed after pause.
    event NYMResumed(address indexed admin);

    /// @notice Event emitted when RewardManager state var is modified.
    event RewardManagerChanged(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Event emitted when stable token is swapped for debtToken.
    event AssetForDebtTokenSwapped(
        address caller, address receiver, address asset, uint256 stableIn, uint256 tokenOut, uint256 fee
    );

    /// @notice Event emitted when stable token is swapped for debtToken.
    event DebtTokenForAssetSwapped(
        address caller, address receiver, address asset, uint256 debtTokenBurnt, uint256 stableOut, uint256 fee
    );

    /// @notice Event emitted when the status of a privileged user is changed.
    event PrivilegedSet(address privileged, bool isPrivileged);

    /// @notice Event emitted when a user schedules a swapOut.
    event WithdrawalScheduled(address asset, address user, uint256 amount, uint256 fee, uint32 time);

    /// @notice Event emitted when a user withdraws the scheduled swapOut.
    event Withdraw(address asset, address user, uint256 amount);

    /// @notice Event emitted when the token is transferred.
    event TokenTransferred(address indexed token, address indexed to, uint256 amount);

    /// @notice Event emitted when the asset configuration is set.
    event AssetConfigSetting(address asset, AssetConfig config);

    /// @notice Event emitted when an asset is sunset.
    event AssetSunset(address asset);

    /// @notice thrown when contract is in paused state
    error Paused();

    /// @notice thrown when attempted to pause an already paused contract
    error AlreadyPaused();

    /// @notice thrown when attempted to resume the contract if it is already resumed
    error NotPaused();

    /// @notice thrown when fee in or fee out is invalid
    error InvalidFee(uint256 feeIn, uint256 feeOut);

    /// @notice thrown when a zero address is passed as a function parameter
    error ZeroAddress();

    /// @notice thrown when a zero amount is passed as stable token amount parameter
    error ZeroAmount();

    /// @notice thrown when the user doesn't have enough debtToken balance to provide for the amount of stable tokens he wishes to get
    error NotEnoughDebtToken(uint256 debtBalance, uint256 stableTknAmount);

    /// @notice thrown when the amount of debtToken to be burnt exceeds the debtTokenMinted amount
    error DebtTokenMintedUnderflow(uint256 debtTokenMinted, uint256 stableTknAmount);

    /// @notice thrown when the debtToken is not enough to transfer
    error DebtTokenNotEnough(uint256 debtTokenAmount, uint256 transferAmount);

    /// @notice thrown when debtToken to be minted will go beyond the mintCap threshold
    error DebtTokenMintCapReached(uint256 debtTokenMinted, uint256 amountToMint, uint256 debtTokenMintCap);

    /// @notice thrown when debtToken to be minted will go beyond the daily mintCap threshold
    error DebtTokenDailyMintCapReached(uint256 dailyMinted, uint256 amountToMint, uint256 dailyDebtTokenMintCap);

    /// @notice thrown when fee calculation will result in rounding down to 0 due to stable token amount being a too small number
    error AmountTooSmall(uint256 feeAmount);

    /// @notice thrown when a user has already scheduled a swapOut
    error WithdrawalAlreadyScheduled(uint32 withdrawalTime);

    /// @notice thrown when a user tries to withdraw before the scheduled time or a user does not have a scheduled swapOut
    error WithdrawalNotAvailable(uint32 withdrawalTime);

    /// @notice thrown when the address is not privileged
    error NotPrivileged(address addr);

    /// @notice thrown when the asset is not supported
    error AssetNotSupported(address asset);

    /// @notice thrown when the price of the asset is greater than the max price or less than the min price
    error InvalidPrice(uint256 price);

    error InvalidSourceChainSender(address, address);

    error InvalidChainId();

    error AssetNotEnough(uint256 assetAmount, uint256 transferAmount);

    /**
     * @notice Sets the configuration for a specific asset.
     * @param asset The address of the asset.
     * @param config The configuration parameters for the asset.
     */
    function setAssetConfig(address asset, AssetConfig calldata config) external;

    /**
     * @notice Sunsets a specific asset, disabling its use.
     * @param asset The address of the asset to sunset.
     */
    function sunsetAsset(address asset) external;

    /**
     * @notice Swaps a specified amount of an asset for debt tokens.
     * @param asset The address of the asset to swap.
     * @param receiver The address to receive the debt tokens.
     * @param assetAmount The amount of the asset to swap.
     * @return The amount of debt tokens received.
     */
    function swapIn(address asset, address receiver, uint256 assetAmount) external returns (uint256);

    /**
     * @notice Pauses the contract, disabling certain functions.
     */
    function pause() external;

    /**
     * @notice Resumes the contract, re-enabling certain functions.
     */
    function resume() external;

    /**
     * @notice Sets the privileged status of an account.
     * @param account The address of the account.
     * @param isPrivileged_ The privileged status to set.
     */
    function setPrivileged(address account, bool isPrivileged_) external;

    /**
     * @notice Transfers a specified amount of tokens to a privileged vault.
     * @param token The address of the token to transfer.
     * @param vault The address of the privileged vault.
     * @param amount The amount of tokens to transfer.
     */
    function transferTokenToPrivilegedVault(address token, address vault, uint256 amount) external;

    /**
     * @notice Previews the amount of debt tokens that would be received for a specified amount of stable tokens.
     * @param asset The address of the asset.
     * @param stableTknAmount The amount of stable tokens.
     * @return The amount of debt tokens and the fee.
     */
    function previewSwapOut(address asset, uint256 stableTknAmount) external returns (uint256, uint256);

    /**
     * @notice Previews the amount of stable tokens that would be received for a specified amount of debt tokens.
     * @param asset The address of the asset.
     * @param stableTknAmount The amount of stable tokens.
     * @return The amount of debt tokens and the fee.
     */
    function previewSwapIn(address asset, uint256 stableTknAmount) external returns (uint256, uint256);

    /**
     * @notice Swaps a specified amount of stable tokens for debt tokens for a privileged account.
     * @param asset The address of the asset.
     * @param receiver The address to receive the debt tokens.
     * @param stableTknAmount The amount of stable tokens to swap.
     * @return The amount of debt tokens received.
     */
    function swapOutPrivileged(address asset, address receiver, uint256 stableTknAmount) external returns (uint256);

    /**
     * @notice Swaps a specified amount of debt tokens for stable tokens for a privileged account.
     * @param asset The address of the asset.
     * @param receiver The address to receive the stable tokens.
     * @param stableTknAmount The amount of stable tokens to swap.
     * @return The amount of debt tokens received.
     */
    function swapInPrivileged(address asset, address receiver, uint256 stableTknAmount) external returns (uint256);

    /**
     * @notice Schedules a swap out of a specified amount of an asset.
     * @param asset The address of the asset.
     * @param amount The amount of the asset to swap out.
     * @return The scheduled time for the swap out.
     */
    function scheduleSwapOut(address asset, uint256 amount) external returns (uint256);

    /**
     * @notice Withdraws a previously scheduled swap out.
     * @param asset The address of the asset.
     */
    function withdraw(address asset) external;

    /**
     * @notice Converts a specified amount of debt tokens to the equivalent amount of an asset.
     * @param asset The address of the asset.
     * @param amount The amount of debt tokens.
     * @return The equivalent amount of the asset.
     */
    function convertDebtTokenToAssetAmount(address asset, uint256 amount) external view returns (uint256);

    /**
     * @notice Converts a specified amount of an asset to the equivalent amount of debt tokens.
     * @param asset The address of the asset.
     * @param amount The amount of the asset.
     * @return The equivalent amount of debt tokens.
     */
    function convertAssetToDebtTokenAmount(address asset, uint256 amount) external view returns (uint256);

    /**
     * @notice Returns the oracle for a specific asset.
     * @param asset The address of the asset.
     * @return The oracle interface.
     */
    function oracle(address asset) external view returns (IPriceFeedAggregatorFacet);

    /**
     * @notice Returns the incoming fee for a specific asset.
     * @param asset The address of the asset.
     * @return The incoming fee.
     */
    function feeIn(address asset) external view returns (uint256);

    /**
     * @notice Returns the outgoing fee for a specific asset.
     * @param asset The address of the asset.
     * @return The outgoing fee.
     */
    function feeOut(address asset) external view returns (uint256);

    /**
     * @notice Returns the mint cap for debt tokens for a specific asset.
     * @param asset The address of the asset.
     * @return The mint cap.
     */
    function debtTokenMintCap(address asset) external view returns (uint256);

    /**
     * @notice Returns the daily mint cap for debt tokens for a specific asset.
     * @param asset The address of the asset.
     * @return The daily mint cap.
     */
    function dailyDebtTokenMintCap(address asset) external view returns (uint256);

    /**
     * @notice Returns the total amount of debt tokens minted for a specific asset.
     * @param asset The address of the asset.
     * @return The total amount of debt tokens minted.
     */
    function debtTokenMinted(address asset) external view returns (uint256);

    /**
     * @notice Returns whether an oracle is being used for a specific asset.
     * @param asset The address of the asset.
     * @return True if an oracle is being used, false otherwise.
     */
    function isUsingOracle(address asset) external view returns (bool);

    /**
     * @notice Returns the waiting period for swaps for a specific asset.
     * @param asset The address of the asset.
     * @return The waiting period.
     */
    function swapWaitingPeriod(address asset) external view returns (uint256);

    /**
     * @notice Returns the remaining daily mint cap for debt tokens for a specific asset.
     * @param asset The address of the asset.
     * @return The remaining daily mint cap.
     */
    function debtTokenDailyMintCapRemain(address asset) external view returns (uint256);

    /**
     * @notice Returns the pending withdrawal amount and time for a specific asset and account.
     * @param asset The address of the asset.
     * @param account The address of the account.
     * @return The pending withdrawal amount and time.
     */
    function pendingWithdrawal(address asset, address account) external view returns (uint256, uint32);

    /**
     * @notice Returns the pending withdrawals for multiple assets and an account.
     * @param assets The array of asset addresses.
     * @param account The address of the account.
     * @return The array of pending withdrawal amounts and times.
     */
    function pendingWithdrawals(address[] memory assets, address account)
        external
        view
        returns (uint256[] memory, uint32[] memory);

    /**
     * @notice Returns whether the contract is paused.
     * @return True if the contract is paused, false otherwise.
     */
    function isNymPaused() external view returns (bool);
    
    /**
     * @notice Returns the daily mint count for a specific asset.
     * @param asset The address of the asset.
     * @return The daily mint count.
     */
    function dailyMintCount(address asset) external view returns (uint256);

    /**
     * @notice Returns whether a specific asset is supported.
     * @param asset The address of the asset.
     * @return True if the asset is supported, false otherwise.
     */
    function isAssetSupported(address asset) external view returns (bool);
}

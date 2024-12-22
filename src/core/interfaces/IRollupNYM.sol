// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRollupNYM {
    /// @notice Thrown when a zero address is encountered
    error ZeroAddress();

    /// @notice Thrown when a zero amount is encountered
    error ZeroAmount();

    /// @notice Thrown when an invalid chain ID is provided
    error InvalidChainId();

    /// @notice Thrown when an unsupported asset is encountered
    /// @param asset The address of the unsupported asset
    error AssetNotSupported(address asset);

    /// @notice Thrown when there is not enough debt token
    /// @param debtBalance The current debt balance
    /// @param amount The amount requested
    error NotEnoughDebtToken(uint256 debtBalance, uint256 amount);

    /// @notice Thrown when there is not enough of the specified asset
    /// @param assetAmount The current amount of the asset
    /// @param _amount The amount requested
    error AssetNotEnough(uint256 assetAmount, uint256 _amount);

    /// @notice Thrown when the caller is not privileged
    /// @param vault The address of the vault
    error NotPrivileged(address vault);

    /// @notice Thrown when the source chain sender is invalid
    /// @param expected The expected address
    /// @param actual The actual address
    error InvalidSourceChainSender(address expected, address actual);

    /// @notice Thrown when the source chain is invalid
    /// @param expected The expected chain ID
    /// @param actual The actual chain ID
    error InvalidSourceChain(uint64 expected, uint64 actual);

    /// @notice Emitted when tokens are transferred
    /// @param token The address of the token
    /// @param vault The address of the vault
    /// @param amount The amount of tokens transferred
    event TokenTransferred(address token, address vault, uint256 amount);

    /// @notice Swaps in an asset to a specified receiver on a destination chain
    /// @param asset The address of the asset to swap
    /// @param receiver The address of the receiver
    /// @param assetAmount The amount of the asset to swap
    /// @param destChainId The ID of the destination chain
    function swapIn(address asset, address receiver, uint256 assetAmount, uint64 destChainId) external payable;

    /// @notice Schedules a swap out of an asset
    /// @param asset The address of the asset to swap out
    /// @param amount The amount of the asset to swap out
    function scheduleSwapOut(address asset, uint256 amount) external payable;

    /// @notice Withdraws a specified amount of an asset
    /// @param asset The address of the asset to withdraw
    /// @param amount The amount of the asset to withdraw
    function withdraw(address asset, uint256 amount) external payable;

    /// @notice Transfers funds
    function transferFund() external;

    /// @notice Transfers a specified amount of an asset to a specified address
    /// @param asset The address of the asset to transfer
    /// @param to The address to transfer the asset to
    /// @param amount The amount of the asset to transfer
    function transferAsset(address asset, address to, uint256 amount) external;

    /// @notice Initializes the contract with specified parameters
    /// @param portal The address of the portal
    /// @param _omniChainNYM The address of the omni-chain NYM
    /// @param debtToken_ The address of the debt token
    /// @param _priceFeedAggregator The address of the price feed aggregator
    function initialize(address portal, address _omniChainNYM, address debtToken_, address _priceFeedAggregator)
        external;

    /// @notice Sets whether an asset is supported
    /// @param asset The address of the asset
    /// @param supported A boolean indicating whether the asset is supported
    function setAssetSupported(address asset, bool supported) external;

    /// @notice Sets whether a chain ID is supported
    /// @param chainId The chain ID
    /// @param supported A boolean indicating whether the chain ID is supported
    function setSupportedChainId(uint64 chainId, bool supported) external;
}

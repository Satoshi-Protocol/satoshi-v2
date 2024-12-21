// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface INYMVault {
    /// @notice Emitted when the strategy address is set
    /// @param strategyAddr The address of the strategy
    event StrategyAddrSet(address strategyAddr);

    /// @notice Emitted when the NYM address is set
    /// @param nymAddr The address of the NYM
    event NYMAddrSet(address nymAddr);

    /// @notice Emitted when tokens are transferred to the strategy
    /// @param amount The amount of tokens transferred
    event TokenTransferredToStrategy(uint256 amount);

    /// @notice Emitted when tokens are transferred to the NYM
    /// @param amount The amount of tokens transferred
    event TokenTransferredToNYM(uint256 amount);

    /// @notice Emitted when tokens are transferred
    /// @param token The address of the token
    /// @param to The address to which tokens are transferred
    /// @param amount The amount of tokens transferred
    event TokenTransferred(address token, address to, uint256 amount);

    /// @notice Emitted when an account is whitelisted or removed from the whitelist
    /// @param account The address of the account
    /// @param status The whitelist status (true for whitelisted, false for removed)
    event WhitelistSet(address account, bool status);

    /// @notice Sets the strategy address
    /// @param _strategyAddr The address of the strategy
    function setStrategyAddr(address _strategyAddr) external;

    /// @notice Sets the NYM address
    /// @param _nymAddr The address of the NYM
    function setNYMAddr(address _nymAddr) external;

    /// @notice Transfers tokens to the NYM
    /// @param amount The amount of tokens to transfer
    function transferTokenToNYM(uint256 amount) external;

    /// @notice Executes a strategy with the provided data
    /// @param data The data required to execute the strategy
    function executeStrategy(bytes calldata data) external;

    /// @notice Exits a strategy with the provided data
    /// @param data The data required to exit the strategy
    /// @return The amount of tokens received upon exiting the strategy
    function exitStrategy(bytes calldata data) external returns (uint256);

    /// @notice Initializes the contract with the provided data
    /// @param data The initialization data
    function initialize(bytes calldata data) external;

    /// @notice Constructs the data required to execute a strategy
    /// @param amount The amount of tokens involved in the strategy
    /// @return The constructed data as bytes
    function constructExecuteStrategyData(uint256 amount) external pure returns (bytes memory);

    /// @notice Constructs the data required to exit a strategy
    /// @param amount The amount of tokens involved in the strategy
    /// @return The constructed data as bytes
    function constructExitStrategyData(uint256 amount) external pure returns (bytes memory);
}

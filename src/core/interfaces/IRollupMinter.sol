// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRollupMinter {
    /// @notice Thrown when the source chain sender is invalid
    /// @param expected The expected address
    /// @param actual The actual address
    error InvalidSourceChainSender(address expected, address actual);

    /// @notice Thrown when the source chain is invalid
    /// @param expected The expected chain ID
    /// @param actual The actual chain ID
    error InvalidSourceChain(uint64 expected, uint64 actual);

    /// @notice Mints tokens to a specified account
    /// @param _account The address of the account to mint tokens to
    /// @param _amount The amount of tokens to mint
    function mint(address _account, uint256 _amount) external;

    /// @notice Burns tokens from a specified account
    /// @param _account The address of the account to burn tokens from
    /// @param _amount The amount of tokens to burn
    function burn(address _account, uint256 _amount) external;
}

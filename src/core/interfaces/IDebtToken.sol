// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {ITroveManager} from "./ITroveManager.sol";

interface IDebtToken is IERC20, IERC20Metadata {
    /**
     * @notice Burns a specific amount of tokens from the specified account.
     * @param _account The address from which the tokens will be burned.
     * @param _amount The amount of tokens to burn.
     */
    function burn(address _account, uint256 _amount) external;

    /**
     * @notice Burns a specific amount of tokens from the specified account with gas compensation.
     * @param _account The address from which the tokens will be burned.
     * @param _amount The amount of tokens to burn.
     * @return A boolean indicating if the operation was successful.
     */
    function burnWithGasCompensation(address _account, uint256 _amount) external returns (bool);

    /**
     * @notice Enables a Trove Manager for the debt token.
     * @param _troveManager The Trove Manager to enable.
     */
    function enableTroveManager(ITroveManager _troveManager) external;

    /**
     * @notice Initiates a flash loan.
     * @param receiver The contract that will receive the flash loan.
     * @param token The address of the token to be loaned.
     * @param amount The amount of tokens to loan.
     * @param data Additional data to pass to the receiver.
     * @return A boolean indicating if the operation was successful.
     */
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        returns (bool);

    /**
     * @notice Mints a specific amount of tokens to the specified account.
     * @param _account The address to which the tokens will be minted.
     * @param _amount The amount of tokens to mint.
     */
    function mint(address _account, uint256 _amount) external;

    /**
     * @notice Mints a specific amount of tokens to the specified account with gas compensation.
     * @param _account The address to which the tokens will be minted.
     * @param _amount The amount of tokens to mint.
     * @return A boolean indicating if the operation was successful.
     */
    function mintWithGasCompensation(address _account, uint256 _amount) external returns (bool);

    /**
     * @notice Returns a specific amount of tokens from a pool to a receiver.
     * @param _poolAddress The address of the pool.
     * @param _receiver The address to receive the tokens.
     * @param _amount The amount of tokens to return.
     */
    function returnFromPool(address _poolAddress, address _receiver, uint256 _amount) external;

    /**
     * @notice Sends a specific amount of tokens to the Stability Pool.
     * @param _sender The address sending the tokens.
     * @param _amount The amount of tokens to send.
     */
    function sendToSP(address _sender, uint256 _amount) external;

    /**
     * @notice Transfers a specific amount of tokens to a recipient.
     * @param recipient The address to receive the tokens.
     * @param amount The amount of tokens to transfer.
     * @return A boolean indicating if the operation was successful.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @notice Transfers a specific amount of tokens from a sender to a recipient.
     * @param sender The address from which the tokens will be transferred.
     * @param recipient The address to receive the tokens.
     * @param amount The amount of tokens to transfer.
     * @return A boolean indicating if the operation was successful.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @notice Returns the gas compensation amount for debt operations.
     * @return The gas compensation amount as a uint256.
     */
    function DEBT_GAS_COMPENSATION() external view returns (uint256);

    /**
     * @notice Returns the flash loan fee.
     * @return The flash loan fee as a uint256.
     */
    function FLASH_LOAN_FEE() external view returns (uint256);

    /**
     * @notice Returns the address of the SatoshiX application.
     * @return The address of the SatoshiX application.
     */
    function satoshiXApp() external view returns (address);

    /**
     * @notice Calculates the flash fee for a given token and amount.
     * @param token The address of the token.
     * @param amount The amount of tokens.
     * @return The flash fee as a uint256.
     */
    function flashFee(address token, uint256 amount) external view returns (uint256);

    /**
     * @notice Returns the maximum flash loan amount for a given token.
     * @param token The address of the token.
     * @return The maximum flash loan amount as a uint256.
     */
    function maxFlashLoan(address token) external view returns (uint256);

    /**
     * @notice Checks if a Trove Manager is enabled.
     * @param _troveManager The Trove Manager to check.
     * @return A boolean indicating if the Trove Manager is enabled.
     */
    function troveManager(ITroveManager _troveManager) external view returns (bool);

    /**
     * @notice Initializes the debt token with the specified parameters.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     * @param _gasPool The address of the gas pool.
     * @param _satoshiXApp The address of the SatoshiX application.
     * @param _owner The address of the owner.
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        address _gasPool,
        address _satoshiXApp,
        address _owner
    ) external;

    /**
     * @notice Checks if an address is authorized as a ward.
     * @param _address The address to check.
     * @return A boolean indicating if the address is a ward.
     */
    function wards(address _address) external view returns (bool);

    /**
     * @notice Grants authorization to an address.
     * @param _address The address to authorize.
     */
    function rely(address _address) external;

    /**
     * @notice Revokes authorization from an address.
     * @param _address The address to deauthorize.
     */
    function deny(address _address) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { VaultCore } from "./VaultCore.sol";
import { IRestakingVault } from "./interfaces/IRestakingVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title CygnusVault
 * @notice A vault contract that manages deposits and withdrawals through Cygnus restaking strategies
 * @dev Inherits from VaultCore and implements strategy management functionality
 */
contract CygnusVault is VaultCore {
    using SafeERC20 for IERC20;

    /**
     * @notice Available operations for strategy execution
     * @param Deposit Deposit tokens into the strategy
     * @param Withdraw Queue a withdrawal request
     * @param Claim Claim a queued withdrawal
     */
    enum Option {
        Deposit,
        RequestWithdraw,
        Claim
    }

    // token -> strategy
    mapping(address => address) public strategy;
    mapping(address => address) public stToken;

    /**
     * @notice Initializes the vault with core components
     * @param data Encoded initialization parameters (vaultManager, debtToken)
     */
    function initialize(bytes calldata data) external override checkInitAddress initializer {
        __UUPSUpgradeable_init_unchained();
        __Ownable_init(msg.sender);
        (address vaultManager_, address debtToken_) = _decodeInitializeData(data);

        vaultManager = vaultManager_;
        debtToken = debtToken_;

        emit VaultManagerSet(vaultManager_);
    }

    /**
     * @notice Executes a strategy operation (deposit, queue withdrawal, or complete withdrawal)
     * @param data Encoded operation parameters
     * @dev Can only be called by the vault manager
     */
    function executeStrategy(bytes calldata data) external override onlyManager {
        Option option = _decodeExecuteData(data);

        if (option == Option.Deposit) {
            _deposit(data[32:]);
        } else if (option == Option.RequestWithdraw) {
            _requestWithdraw(data[32:]);
        } else if (option == Option.Claim) {
            _claim(data[32:]);
        } else {
            revert InvalidOption(uint256(option));
        }
    }

    /**
     * @notice Sets the strategy address for a specific token
     * @param token The token address
     * @param strategy_ The strategy address for the token
     * @dev Can only be called by the owner
     */
    function setTokenStrategy(address token, address strategy_) external onlyOwner {
        strategy[token] = strategy_;
        emit TokenStrategySet(token, strategy_);
    }

    function setStToken(address token, address stToken_) external onlyOwner {
        stToken[token] = stToken_;
        emit STTokenSet(token, stToken_);
    }

    // --- View functions ---

    function constructDepositData(address token, uint256 amount) external pure returns (bytes memory) {
        return abi.encode(Option.Deposit, token, amount);
    }

    function constructRequestWithdrawData(address token, uint256 amount) external pure returns (bytes memory) {
        return abi.encode(Option.RequestWithdraw, token, amount);
    }

    function constructClaimData(address token) external pure returns (bytes memory) {
        return abi.encode(Option.Claim, token);
    }

    function constructExitByTroveManagerData(address, uint256) external pure override returns (bytes memory) {
        revert();
    }

    function decodeTokenAddress(bytes calldata data) external pure override returns (address) {
        address token;
        Option option = _decodeExecuteData(data);
        if (option == Option.Deposit) {
            (token,) = _decodeDepositData(data[32:]);
        } else if (option == Option.RequestWithdraw) {
            (token,) = _decodeRequestWithdrawData(data[32:]);
        } else if (option == Option.Claim) {
            (token,) = _decodeClaimData(data[32:]);
        } else {
            revert InvalidOption(uint256(option));
        }

        return token;
    }

    function getPosition(address token) external view override returns (uint256) {
        return IERC20(stToken[token]).balanceOf(address(this));
    }

    function getOrdersByOwner(address token) external view returns (IRestakingVault.WithdrawOrder[] memory) {
        return IRestakingVault(strategy[token]).getOrdersByOwner(address(this));
    }

    // --- Internal functions ---

    /**
     * @notice Deposits tokens into the restaking strategy
     * @param data Encoded deposit parameters (token, amount)
     */
    function _deposit(bytes calldata data) internal {
        (address token, uint256 amount) = _decodeDepositData(data);
        IERC20(token).safeTransferFrom(vaultManager, address(this), amount);
        IERC20(token).approve(strategy[token], amount);
        IRestakingVault(strategy[token]).deposit(amount);

        emit DepositToCygnusStrategy(token, strategy[token], amount);
    }

    /**
     * @notice Queues a withdrawal request
     * @param data Encoded withdrawal parameters (token, amount)
     */
    function _requestWithdraw(bytes calldata data) internal {
        (address token, uint256 amount) = _decodeRequestWithdrawData(data);
        IERC20(stToken[token]).approve(strategy[token], amount);
        IRestakingVault(strategy[token]).requestWithdraw(amount);

        emit RequestWithdrawFromCygnusStrategy(token, strategy[token], amount);
    }

    /**
     * @notice Completes a queued withdrawal
     * @param data Encoded completion parameters (token)
     */
    function _claim(bytes calldata data) internal {
        (address token, uint256 index) = _decodeClaimData(data);

        uint256[] memory indexes = new uint256[](1);
        indexes[0] = index;
        IRestakingVault(strategy[token]).claim(indexes);

        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(vaultManager, balance);

        emit ClaimOnCygnus(token, index);
    }

    function _decodeInitializeData(bytes calldata data) internal pure returns (address, address) {
        return abi.decode(data, (address, address));
    }

    function _decodeDepositData(bytes calldata data) internal pure returns (address, uint256) {
        return abi.decode(data, (address, uint256));
    }

    function _decodeRequestWithdrawData(bytes calldata data) internal pure returns (address, uint256) {
        return abi.decode(data, (address, uint256));
    }

    function _decodeClaimData(bytes calldata data) internal pure returns (address, uint256) {
        return abi.decode(data, (address, uint256));
    }

    function _decodeExecuteData(bytes calldata data) internal pure returns (Option) {
        return abi.decode(data, (Option));
    }
}

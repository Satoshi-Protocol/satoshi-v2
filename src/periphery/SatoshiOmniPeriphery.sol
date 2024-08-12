// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {XApp} from "lib/omni/contracts/core/src/pkg/XApp.sol";
import {ConfLevel} from "lib/omni/contracts/core/src/libraries/ConfLevel.sol";
import {IPriceFeedAggregator} from "./interfaces/core/IPriceFeedAggregator.sol";
import {IDebtToken} from "./interfaces/core/IDebtToken.sol";
import {ISatoshiOmniPeriphery} from "./interfaces/core/ISatoshiOmniPeriphery.sol";
import {INexusYieldManager} from "./interfaces/core/INexusYieldManager.sol";

contract SatoshiOmniPeriphery is ISatoshiOmniPeriphery, XApp, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /**
     * @notice Gas limit used for a cross-chain greet call at destination
     */
    uint64 public constant DEST_TX_GAS_LIMIT = 2000_000;

    address public omniChainNYM;

    IPriceFeedAggregator public priceFeedAggregator;

    IDebtToken public debtToken;

    mapping(address => bool) public isAssetSupported;

    mapping(uint64 => bool) public supportedChainIds;

    /// @notice The mapping of privileged addresses.
    mapping(address => bool) public isPrivileged;

    mapping(address => uint256) public assetBalances;

    constructor(address portal) XApp(portal, ConfLevel.Latest) {
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation) internal view override {}

    function initialize(address portal, address _omniChainNYM, address debtToken_, address _priceFeedAggregator)
        external
        initializer
    {
        _setOmniPortal(portal);
        _setDefaultConfLevel(ConfLevel.Latest);
        omniChainNYM = _omniChainNYM;
        debtToken = IDebtToken(debtToken_);
        priceFeedAggregator = IPriceFeedAggregator(_priceFeedAggregator);
    }

    modifier onlyXCall() {
        require(isXCall(), "SatoshiOmniPeriphery: only xcall");
        _;
    }

    /* Admin Functions */

    function setSupportedChainId(uint64 chainId, bool supported) external {
        supportedChainIds[chainId] = supported;
    }

    function setAssetSupported(address asset, bool supported) external {
        isAssetSupported[asset] = supported;
    }

    function setPrivileged(address account, bool isPrivileged_) external {
        isPrivileged[account] = isPrivileged_;
    }

    function setOmniChainNYM(address _omniChainNYM) external {
        omniChainNYM = _omniChainNYM;
    }

    /* External Functions */

    function swapIn(address asset, address receiver, uint256 assetAmount, uint64 destChainId) external payable {
        _ensureAssetSupported(asset);
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(assetAmount);
        _ensureChainIdSupported(destChainId);

        // transfer IN, supporting fee-on-transfer tokens
        uint256 balanceBefore = IERC20(asset).balanceOf(address(this));
        IERC20(asset).safeTransferFrom(msg.sender, address(this), assetAmount);
        uint256 balanceAfter = IERC20(asset).balanceOf(address(this));

        // calculate actual transfered amount (in case of fee-on-transfer tokens)
        uint256 actualTransferAmt = balanceAfter - balanceBefore;
        assetBalances[asset] += actualTransferAmt;

        uint256 price; // = priceFeedAggregator.fetchPrice(asset);

        bytes memory data = abi.encodeWithSelector(
            INexusYieldManager.swapIn.selector, asset, receiver, actualTransferAmt, destChainId, price
        );

        // Calculate the cross-chain call fee
        uint256 fee = xcall(omni.omniChainId(), omniChainNYM, data, DEST_TX_GAS_LIMIT);

        // Ensure that the caller provides sufficient value to cover the fee
        require(msg.value >= fee, "RollupNYM: little fee");
    }

    function scheduleSwapOut(address asset, uint256 amount) external payable {
        _ensureNonzeroAmount(amount);
        _ensureAssetSupported(asset);

        uint256 debtBalance = debtToken.balanceOf(msg.sender);
        if (debtBalance < amount) {
            revert NotEnoughDebtToken(debtBalance, amount);
        }

        // check the asset balance is enough to swap out
        if (assetBalances[asset] < amount) {
            revert AssetNotEnough(assetBalances[asset], amount);
        }
        assetBalances[asset] -= amount;

        uint256 price; // = priceFeedAggregator.fetchPrice(asset);

        bytes memory data =
            abi.encodeWithSelector(INexusYieldManager.scheduleSwapOut.selector, msg.sender, asset, amount, price);

        // Calculate the cross-chain call fee
        uint256 fee = xcall(omni.omniChainId(), omniChainNYM, data, DEST_TX_GAS_LIMIT);

        // Ensure that the caller provides sufficient value to cover the fee
        require(msg.value >= fee, "RollupNYM: little fee");
    }

    function withdraw(address asset, uint256 amount) external payable {
        _ensureAssetSupported(asset);

        // check the asset balance is enough to withdraw
        uint256 assetAmount = IERC20(asset).balanceOf(address(this));
        if (assetAmount < amount) {
            revert AssetNotEnough(assetAmount, amount);
        }

        bytes memory data = abi.encodeWithSelector(INexusYieldManager.withdraw.selector, msg.sender, asset, amount);

        // Calculate the cross-chain call fee
        uint256 fee = xcall(omni.omniChainId(), omniChainNYM, data, DEST_TX_GAS_LIMIT);

        // Ensure that the caller provides sufficient value to cover the fee
        require(msg.value >= fee, "RollupNYM: little fee");
    }

    function handleSwapInRevert(address asset, address account, uint256 assetAmount) external xrecv onlyXCall {
        _ensureSourceChainIsOmni();
        _ensureSourceChainSender();
        _ensureAssetSupported(asset);

        assetBalances[asset] -= assetAmount;
        IERC20(asset).transfer(account, assetAmount);
    }

    // this function will be removed in the future
    // for transferring the eth to the owner
    function transferFund() external {
        payable(msg.sender).transfer(address(this).balance);
    }

    function transferAsset(address asset, address to, uint256 amount) external xrecv onlyXCall {
        _ensureNonzeroAddress(to);
        _ensureNonzeroAmount(amount);
        _ensureAssetSupported(asset);
        _ensureSourceChainIsOmni();
        _ensureSourceChainSender();

        IERC20(asset).safeTransfer(to, amount);
    }

    function transerTokenToPrivilegedVault(address token, address vault, uint256 amount) external {
        if (!isPrivileged[vault]) {
            revert NotPrivileged(vault);
        }
        IERC20(token).transfer(vault, amount);
        emit TokenTransferred(token, vault, amount);
    }

    function _ensureNonzeroAddress(address someone) private pure {
        if (someone == address(0)) revert ZeroAddress();
    }

    function _ensureNonzeroAmount(uint256 amount) private pure {
        if (amount == 0) revert ZeroAmount();
    }

    function _ensureChainIdSupported(uint64 chainId) private view {
        if (!supportedChainIds[chainId]) revert InvalidChainId();
    }

    function _ensureAssetSupported(address asset) private view {
        if (!isAssetSupported[asset]) {
            revert AssetNotSupported(asset);
        }
    }

    function _ensureSourceChainIsOmni() private view {
        if (xmsg.sourceChainId != omni.omniChainId()) {
            revert InvalidSourceChain(xmsg.sourceChainId, omni.omniChainId());
        }
    }

    function _ensureSourceChainSender() private view {
        if (xmsg.sender != omniChainNYM) {
            revert InvalidSourceChainSender(xmsg.sender, omniChainNYM);
        }
    }

    receive() external payable {}
}

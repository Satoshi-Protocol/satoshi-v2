// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {XApp} from "lib/omni/contracts/core/src/pkg/XApp.sol";
import {ConfLevel} from "lib/omni/contracts/core/src/libraries/ConfLevel.sol";
import {IDebtToken} from "./interfaces/core/IDebtToken.sol";
import {IRollupMinter} from "./interfaces/core/IRollupMinter.sol";

// Responsible for minting/burning debt tokens on the Rollup chain
contract RollupMinter is IRollupMinter, XApp, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /**
     * @notice Gas limit used for a cross-chain greet call at destination
     */
    address public omniChainNYM;

    IDebtToken public debtToken;

    mapping(address => bool) public isAssetSupported;

    mapping(uint64 => bool) public supportedChainIds;

    constructor(address portal) XApp(portal, ConfLevel.Latest) {
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation) internal view override {}

    function initialize(address portal, address _omniChainNYM, address debtToken_) external initializer {
        _setOmniPortal(portal);
        _setDefaultConfLevel(ConfLevel.Latest);
        omniChainNYM = _omniChainNYM;
        debtToken = IDebtToken(debtToken_);
    }

    modifier onlyXCall() {
        require(isXCall(), "Minter: only xcall");
        _;
    }

    function setOminChainNYM(address _omniChainNYM) external {
        omniChainNYM = _omniChainNYM;
    }

    function setPortal(address _portal) external {
        _setOmniPortal(_portal);
    }

    function setConfLevel(uint8 _confLevel) external {
        _setDefaultConfLevel(_confLevel);
    }

    function setDebtToken(address _debtToken) external {
        debtToken = IDebtToken(_debtToken);
    }

    /* External Functions */

    function mint(address _account, uint256 _amount) external xrecv onlyXCall {
        _ensureSourceChainSender();
        _ensureSourceChainIsOmni();

        debtToken.mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external xrecv onlyXCall {
        _ensureSourceChainSender();
        _ensureSourceChainIsOmni();

        debtToken.burn(_account, _amount);
    }

    function _ensureSourceChainSender() private view {
        if (xmsg.sender != omniChainNYM) {
            revert InvalidSourceChainSender(xmsg.sender, omniChainNYM);
        }
    }

    function _ensureSourceChainIsOmni() private view {
        if (xmsg.sourceChainId != omni.omniChainId()) {
            revert InvalidSourceChain(xmsg.sourceChainId, omni.omniChainId());
        }
    }

    receive() external payable {}
}

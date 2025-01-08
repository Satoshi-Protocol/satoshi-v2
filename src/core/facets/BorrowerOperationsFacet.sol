// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AccessControlInternal} from "@solidstate/contracts/access/access_control/AccessControlInternal.sol";
import {OwnableInternal} from "@solidstate/contracts/access/ownable/OwnableInternal.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AppStorage} from "../AppStorage.sol";
import {SatoshiMath} from "../../library/SatoshiMath.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {IDebtToken} from "../interfaces/IDebtToken.sol";
import {
    IBorrowerOperationsFacet,
    BorrowerOperation,
    TroveManagerData,
    Balances
} from "../interfaces/IBorrowerOperationsFacet.sol";
import {IRewardManager} from "../../OSHI/interfaces/IRewardManager.sol";
import {Config} from "../Config.sol";
import {BorrowerOperationsLib} from "../libs/BorrowerOperationsLib.sol";
/**
 * @title Borrower Operations Contract (Upgradable)
 *        Mutated from:
 *        https://github.com/prisma-fi/prisma-contracts/blob/main/contracts/core/BorrowerOperations.sol
 *        https://github.com/liquity/dev/blob/main/packages/contracts/contracts/BorrowerOperations.sol
 *
 */

contract BorrowerOperationsFacet is IBorrowerOperationsFacet, AccessControlInternal {
    using SafeERC20 for IERC20;
    using SafeERC20 for IDebtToken;
    using BorrowerOperationsLib for *;

    // IFactory public factory;

    struct LocalVariables_adjustTrove {
        uint256 price;
        uint256 totalPricedCollateral;
        uint256 totalDebt;
        uint256 collChange;
        uint256 netDebtChange;
        bool isCollIncrease;
        uint256 debt;
        uint256 coll;
        uint256 newDebt;
        uint256 newColl;
        uint256 stake;
        uint256 debtChange;
        address account;
        uint256 MCR;
    }

    struct LocalVariables_openTrove {
        uint256 price;
        uint256 totalPricedCollateral;
        uint256 totalDebt;
        uint256 netDebt;
        uint256 compositeDebt;
        uint256 ICR;
        uint256 NICR;
        uint256 stake;
        uint256 arrayIndex;
    }

    // constructor() {
    //     _disableInitializers();
    // }

    // /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // // solhint-disable-next-line no-empty-blocks
    // function _authorizeUpgrade(address newImplementation) internal view override onlyRole(Config.OWNER_ROLE) {
    //     // No additional authorization logic is needed for this contract
    // }

    // function initialize(
    //     ISatoshiCore _satoshiCore,
    //     IDebtToken _debtToken,
    //     IFactory _factory,
    //     uint256 _minNetDebt,
    //     uint256 _gasCompensation
    // ) external initializer {
    //     __UUPSUpgradeable_init_unchained();
    //     __SatoshiOwnable_init(_satoshiCore);
    //     __SatoshiBase_init(_gasCompensation);
    //     debtToken = _debtToken;
    //     factory = _factory;
    //     _setMinNetDebt(_minNetDebt);
    // }

    function isApprovedDelegate(address _account, address _delegate) external view returns (bool) {
        return AppStorage.layout().isApprovedDelegate[_account][_delegate];
    }

    function setDelegateApproval(address _delegate, bool _isApproved) external {
        AppStorage.Layout storage s = AppStorage.layout();
        s.isApprovedDelegate[msg.sender][_delegate] = _isApproved;
        emit DelegateApprovalSet(msg.sender, _delegate, _isApproved);
    }

    function setMinNetDebt(uint256 _minNetDebt) external onlyRole(Config.OWNER_ROLE) {
        _setMinNetDebt(_minNetDebt);
    }

    function _setMinNetDebt(uint256 _minNetDebt) internal {
        require(_minNetDebt != 0, "BorrowerOps: Min net debt must be greater than 0");
        AppStorage.Layout storage s = AppStorage.layout();
        s.minNetDebt = _minNetDebt;
        emit MinNetDebtUpdated(_minNetDebt);
    }

    function removeTroveManager(ITroveManager troveManager) external {
        AppStorage.Layout storage s = AppStorage.layout();
        TroveManagerData memory tmData = s.troveManagersData[troveManager];
        require(
            address(tmData.collateralToken) != address(0) && troveManager.sunsetting()
                && troveManager.getEntireSystemDebt() == 0,
            "Trove Manager cannot be removed"
        );
        delete s.troveManagersData[troveManager];
        uint256 lastIndex = s.troveManagers.length - 1;
        if (tmData.index < lastIndex) {
            ITroveManager lastTm = s.troveManagers[lastIndex];
            s.troveManagers[tmData.index] = lastTm;
            s.troveManagersData[lastTm].index = tmData.index;
        }

        s.troveManagers.pop();
        emit TroveManagerRemoved(troveManager);
    }

    /**
     * @notice Get the global total collateral ratio
     *     @dev Not a view because fetching from the oracle is state changing.
     *          Can still be accessed as a view from within the UX.
     */
    function getTCR() external returns (uint256 globalTotalCollateralRatio) {
        AppStorage.Layout storage s = AppStorage.layout();
        Balances memory balances = s._fetchBalances();
        (globalTotalCollateralRatio,,) = BorrowerOperationsLib._getTCRData(balances);
        return globalTotalCollateralRatio;
    }

    function fetchBalances() external returns (Balances memory balances) {
        return BorrowerOperationsLib._fetchBalances(AppStorage.layout());
    }

    function checkRecoveryMode(uint256 TCR) external pure returns (bool) {
        return BorrowerOperationsLib._checkRecoveryMode(TCR);
    }

    function getCompositeDebt(uint256 _debt) external pure returns (uint256) {
        return SatoshiMath._getCompositeDebt(_debt);
    }

    // --- Borrower Trove Operations ---

    function openTrove(
        ITroveManager troveManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _collateralAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external {
        AppStorage.Layout storage s = AppStorage.layout();
        require(!s.paused, "Deposits are paused");
        require(s._isCallerOrDelegated(account), "Caller not approved");

        IERC20 collateralToken;
        LocalVariables_openTrove memory vars;
        bool isRecoveryMode;

        (collateralToken, vars.price, vars.totalPricedCollateral, vars.totalDebt, isRecoveryMode) =
            s._getCollateralAndTCRData(troveManager);

        BorrowerOperationsLib._requireValidMaxFeePercentage(_maxFeePercentage);

        vars.netDebt = _debtAmount
            + _triggerBorrowingFee(s, troveManager, collateralToken, account, _maxFeePercentage, _debtAmount);

        BorrowerOperationsLib._requireAtLeastMinNetDebt(s, vars.netDebt);

        uint8 decimals = IERC20Metadata(address(collateralToken)).decimals();
        uint256 scaledCollateralAmount = SatoshiMath._getScaledCollateralAmount(_collateralAmount, decimals);

        // ICR is based on the composite debt, i.e. the requested Debt amount + Debt borrowing fee + Debt gas comp.
        vars.compositeDebt = SatoshiMath._getCompositeDebt(vars.netDebt);
        vars.ICR = SatoshiMath._computeCR(scaledCollateralAmount, vars.compositeDebt, vars.price);
        vars.NICR = SatoshiMath._computeNominalCR(_collateralAmount, vars.compositeDebt);

        if (isRecoveryMode) {
            BorrowerOperationsLib._requireICRisAboveCCR(vars.ICR);
        } else {
            BorrowerOperationsLib._requireICRisAboveMCR(vars.ICR, troveManager.MCR());
            uint256 newTCR = BorrowerOperationsLib._getNewTCRFromTroveChange(
                vars.totalPricedCollateral,
                vars.totalDebt,
                _collateralAmount * vars.price,
                true,
                vars.compositeDebt,
                true,
                decimals
            ); // bools: coll increase, debt increase
            BorrowerOperationsLib._requireNewTCRisAboveCCR(newTCR);
        }

        // Create the trove
        (vars.stake, vars.arrayIndex) =
            troveManager.openTrove(account, _collateralAmount, vars.compositeDebt, vars.NICR, _upperHint, _lowerHint);

        // Move the collateral to the Trove Manager
        collateralToken.safeTransferFrom(msg.sender, address(troveManager), _collateralAmount);

        //  and mint the DebtAmount to the caller and gas compensation for Gas Pool
        s.debtToken.mintWithGasCompensation(msg.sender, _debtAmount);

        // collect interest payable to rewardManager
        if (troveManager.interestPayable() != 0) {
            troveManager.collectInterests();
        }
    }

    // Send collateral to a trove
    function addColl(
        ITroveManager troveManager,
        address account,
        uint256 _collateralAmount,
        address _upperHint,
        address _lowerHint
    ) external {
        AppStorage.Layout storage s = AppStorage.layout();
        require(!s.paused, "Trove adjustments are paused");
        require(s._isCallerOrDelegated(account), "Caller not approved");

        _adjustTrove(s, troveManager, account, 0, _collateralAmount, 0, 0, false, _upperHint, _lowerHint);

        // collect interest payable to rewardManager
        if (troveManager.interestPayable() != 0) {
            troveManager.collectInterests();
        }
    }

    // Withdraw collateral from a trove
    function withdrawColl(
        ITroveManager troveManager,
        address account,
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint
    ) external {
        AppStorage.Layout storage s = AppStorage.layout();
        require(s._isCallerOrDelegated(account), "Caller not approved");
        _adjustTrove(s, troveManager, account, 0, 0, _collWithdrawal, 0, false, _upperHint, _lowerHint);

        // collect interest payable to rewardManager
        if (troveManager.interestPayable() != 0) {
            troveManager.collectInterests();
        }
    }

    // Withdraw Debt tokens from a trove: mint new Debt tokens to the owner, and increase the trove's debt accordingly
    function withdrawDebt(
        ITroveManager troveManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external {
        AppStorage.Layout storage s = AppStorage.layout();
        require(!s.paused, "Withdrawals are paused");
        require(s._isCallerOrDelegated(account), "Caller not approved");
        _adjustTrove(s, troveManager, account, _maxFeePercentage, 0, 0, _debtAmount, true, _upperHint, _lowerHint);

        // collect interest payable to rewardManager
        if (troveManager.interestPayable() != 0) {
            troveManager.collectInterests();
        }
    }

    // Repay Debt tokens to a Trove: Burn the repaid Debt tokens, and reduce the trove's debt accordingly
    function repayDebt(
        ITroveManager troveManager,
        address account,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external {
        AppStorage.Layout storage s = AppStorage.layout();
        require(s._isCallerOrDelegated(account), "Caller not approved");
        _adjustTrove(s, troveManager, account, 0, 0, 0, _debtAmount, false, _upperHint, _lowerHint);

        // collect interest payable to rewardManager
        if (troveManager.interestPayable() != 0) {
            troveManager.collectInterests();
        }
    }

    function adjustTrove(
        ITroveManager troveManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external {
        AppStorage.Layout storage s = AppStorage.layout();
        require((_collDeposit == 0 && !_isDebtIncrease) || !s.paused, "Trove adjustments are paused");
        require(_collDeposit == 0 || _collWithdrawal == 0, "BorrowerOperations: Cannot withdraw and add coll");
        require(s._isCallerOrDelegated(account), "Caller not approved");
        _adjustTrove(
            s,
            troveManager,
            account,
            _maxFeePercentage,
            _collDeposit,
            _collWithdrawal,
            _debtChange,
            _isDebtIncrease,
            _upperHint,
            _lowerHint
        );

        // collect interest payable to rewardManager
        if (troveManager.interestPayable() != 0) {
            troveManager.collectInterests();
        }
    }

    function _adjustTrove(
        AppStorage.Layout storage s,
        ITroveManager troveManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) internal {
        require(
            _collDeposit != 0 || _collWithdrawal != 0 || _debtChange != 0,
            "BorrowerOps: There must be either a collateral change or a debt change"
        );

        IERC20 collateralToken;
        LocalVariables_adjustTrove memory vars;
        bool isRecoveryMode;
        (collateralToken, vars.price, vars.totalPricedCollateral, vars.totalDebt, isRecoveryMode) =
            s._getCollateralAndTCRData(troveManager);

        (vars.coll, vars.debt) = troveManager.applyPendingRewards(account);

        // Get the collChange based on whether or not collateral was sent in the transaction
        (vars.collChange, vars.isCollIncrease) = BorrowerOperationsLib._getCollChange(_collDeposit, _collWithdrawal);
        vars.netDebtChange = _debtChange;
        vars.debtChange = _debtChange;
        vars.account = account;
        vars.MCR = troveManager.MCR();

        if (_isDebtIncrease) {
            require(_debtChange != 0, "BorrowerOps: Debt increase requires non-zero debtChange");
            BorrowerOperationsLib._requireValidMaxFeePercentage(_maxFeePercentage);

            vars.netDebtChange +=
                _triggerBorrowingFee(s, troveManager, collateralToken, account, _maxFeePercentage, _debtChange);
        }

        // Calculate old and new ICRs and check if adjustment satisfies all conditions for the current system mode
        uint8 decimals = IERC20Metadata(address(collateralToken)).decimals();
        _requireValidAdjustmentInCurrentMode(
            vars.totalPricedCollateral, vars.totalDebt, isRecoveryMode, _collWithdrawal, _isDebtIncrease, vars, decimals
        );

        // When the adjustment is a debt repayment, check it's a valid amount and that the caller has enough Debt
        if (!_isDebtIncrease && _debtChange != 0) {
            BorrowerOperationsLib._requireAtLeastMinNetDebt(s, SatoshiMath._getNetDebt(vars.debt) - vars.netDebtChange);
        }

        // If we are incrasing collateral, send tokens to the trove manager prior to adjusting the trove
        if (vars.isCollIncrease) collateralToken.safeTransferFrom(msg.sender, address(troveManager), vars.collChange);

        (vars.newColl, vars.newDebt, vars.stake) = troveManager.updateTroveFromAdjustment(
            _isDebtIncrease,
            vars.debtChange,
            vars.netDebtChange,
            vars.isCollIncrease,
            vars.collChange,
            _upperHint,
            _lowerHint,
            vars.account,
            msg.sender
        );
    }

    function closeTrove(ITroveManager troveManager, address account) external {
        AppStorage.Layout storage s = AppStorage.layout();
        require(s._isCallerOrDelegated(account), "Caller not approved");

        IERC20 collateralToken;
        uint256 price;
        bool isRecoveryMode;
        uint256 totalPricedCollateral;
        uint256 totalDebt;
        (collateralToken, price, totalPricedCollateral, totalDebt, isRecoveryMode) =
            s._getCollateralAndTCRData(troveManager);
        require(!isRecoveryMode, "BorrowerOps: Operation not permitted during Recovery Mode");
        uint8 decimals = IERC20Metadata(address(collateralToken)).decimals();
        (uint256 coll, uint256 debt) = troveManager.applyPendingRewards(account);

        uint256 newTCR = BorrowerOperationsLib._getNewTCRFromTroveChange(
            totalPricedCollateral, totalDebt, coll * price, false, debt, false, decimals
        );

        BorrowerOperationsLib._requireNewTCRisAboveCCR(newTCR);

        troveManager.closeTrove(account, msg.sender, coll, debt);

        // Burn the repaid Debt from the user's balance and the gas compensation from the Gas Pool
        s.debtToken.burnWithGasCompensation(msg.sender, debt - Config.DEBT_GAS_COMPENSATION);

        // collect interest payable to rewardManager
        if (troveManager.interestPayable() != 0) {
            troveManager.collectInterests();
        }
    }

    function troveManagersData(ITroveManager _troveManager) external view returns (IERC20, uint16) {
        TroveManagerData memory _troveManagersData = AppStorage.layout().troveManagersData[_troveManager];
        return (_troveManagersData.collateralToken, _troveManagersData.index);
    }

    function minNetDebt() external view returns (uint256) {
        return AppStorage.layout().minNetDebt;
    }

    // --- Helper functions ---

    function _triggerBorrowingFee(
        AppStorage.Layout storage s,
        ITroveManager _troveManager,
        IERC20 collateralToken,
        address _caller,
        uint256 _maxFeePercentage,
        uint256 _debtAmount
    ) internal returns (uint256) {
        uint256 debtFee = _troveManager.decayBaseRateAndGetBorrowingFee(_debtAmount);

        SatoshiMath._requireUserAcceptsFee(debtFee, _debtAmount, _maxFeePercentage);

        address rewardManager = address(s.rewardManager);
        s.debtToken.mint(address(this), debtFee);
        s.debtToken.safeIncreaseAllowance(rewardManager, debtFee);
        IRewardManager(rewardManager).increaseSATPerUintStaked(debtFee);

        emit BorrowingFeePaid(_caller, collateralToken, debtFee);

        return debtFee;
    }

    function _requireValidAdjustmentInCurrentMode(
        uint256 totalPricedCollateral,
        uint256 totalDebt,
        bool _isRecoveryMode,
        uint256 _collWithdrawal,
        bool _isDebtIncrease,
        LocalVariables_adjustTrove memory _vars,
        uint8 decimals
    ) internal pure {
        /*
         *In Recovery Mode, only allow:
         *
         * - Pure collateral top-up
         * - Pure debt repayment
         * - Collateral top-up with debt repayment
         * - A debt increase combined with a collateral top-up which makes the ICR >= 150% and improves the ICR (and by extension improves the TCR).
         *
         * In Normal Mode, ensure:
         *
         * - The new ICR is above MCR
         * - The adjustment won't pull the TCR below CCR
         */

        // Get the trove's old ICR before the adjustment
        uint256 scaledCollAmount = SatoshiMath._getScaledCollateralAmount(_vars.coll, decimals);
        uint256 oldICR = SatoshiMath._computeCR(scaledCollAmount, _vars.debt, _vars.price);

        // Get the trove's new ICR after the adjustment
        uint256 newICR = BorrowerOperationsLib._getNewICRFromTroveChange(
            _vars.coll,
            _vars.debt,
            _vars.collChange,
            _vars.isCollIncrease,
            _vars.netDebtChange,
            _isDebtIncrease,
            _vars.price,
            decimals
        );

        if (_isRecoveryMode) {
            require(_collWithdrawal == 0, "BorrowerOps: Collateral withdrawal not permitted Recovery Mode");
            if (_isDebtIncrease) {
                BorrowerOperationsLib._requireICRisAboveCCR(newICR);
                BorrowerOperationsLib._requireNewICRisAboveOldICR(newICR, oldICR);
            }
        } else {
            // if Normal Mode
            BorrowerOperationsLib._requireICRisAboveMCR(newICR, _vars.MCR);
            uint256 newTCR = BorrowerOperationsLib._getNewTCRFromTroveChange(
                totalPricedCollateral,
                totalDebt,
                _vars.collChange * _vars.price,
                _vars.isCollIncrease,
                _vars.netDebtChange,
                _isDebtIncrease,
                decimals
            );
            BorrowerOperationsLib._requireNewTCRisAboveCCR(newTCR);
        }
    }

    function getGlobalSystemBalances() external returns (uint256 totalPricedCollateral, uint256 totalDebt) {
        AppStorage.Layout storage s = AppStorage.layout();
        Balances memory balances = s._fetchBalances();
        (, totalPricedCollateral, totalDebt) = BorrowerOperationsLib._getTCRData(balances);
    }
}

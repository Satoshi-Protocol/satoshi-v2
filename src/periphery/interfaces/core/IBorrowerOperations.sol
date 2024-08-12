// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "./ISatoshiCore.sol";
import {ISatoshiBase} from "../dependencies/ISatoshiBase.sol";
import {ISatoshiOwnable} from "../dependencies/ISatoshiOwnable.sol";
import {IDelegatedOps} from "../dependencies/IDelegatedOps.sol";
import {IDebtToken} from "./IDebtToken.sol";

enum BorrowerOperation {
    openTrove,
    closeTrove,
    adjustTrove
}

struct Balances {
    uint256[] collaterals;
    uint256[] debts;
    uint256[] prices;
    uint8[] decimals;
}

struct TroveManagerData {
    IERC20 collateralToken;
    uint16 index;
}

interface IBorrowerOperations is ISatoshiOwnable, ISatoshiBase, IDelegatedOps {
    function addColl(
        uint64 chain,
        address asset,
        address _account,
        uint256 _collateralAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function adjustTrove(
        uint64 chain,
        address asset,
        address _account,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external;

    function closeTrove(uint64 chain, address asset, address _account) external;

    function configureCollateral(uint64 chain, address asset, IERC20 _collateralToken) external;

    function fetchBalances() external returns (Balances memory balances);

    function getGlobalSystemBalances() external returns (uint256 totalPricedCollateral, uint256 totalDebt);

    function getTCR() external returns (uint256 globalTotalCollateralRatio);

    function openTrove(
        uint64 chain,
        address asset,
        address _account,
        uint256 _maxFeePercentage,
        uint256 _collateralAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function repayDebt(
        uint64 chain,
        address asset,
        address _account,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function setMinNetDebt(uint256 _minNetDebt) external;

    function withdrawColl(
        uint64 chain,
        address asset,
        address _account,
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint
    ) external;

    function withdrawDebt(
        uint64 chain,
        address asset,
        address _account,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function checkRecoveryMode(uint256 TCR) external pure returns (bool);

    function debtToken() external view returns (IDebtToken);

    function getCompositeDebt(uint256 _debt) external view returns (uint256);

    function minNetDebt() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {ISatoshiOwnable} from "../dependencies/ISatoshiOwnable.sol";
// import {IDebtToken} from "./IDebtToken.sol";
// import {IFactory} from "./IFactory.sol";
// import {ILiquidationManager} from "./ILiquidationManager.sol";
// import {ICommunityIssuance} from "./ICommunityIssuance.sol";

struct AccountDeposit {
    uint128 amount;
    uint128 timestamp; // timestamp of the last deposit
}

struct Snapshots {
    uint256 P;
    uint256 G;
    uint128 scale;
    uint128 epoch;
}

struct SunsetIndex {
    uint128 idx;
    uint128 expiry;
}

struct Queue {
    uint16 firstSunsetIndexKey;
    uint16 nextSunsetIndexKey;
}

interface IStabilityPoolFacet {
    event CollateralGainWithdrawn(address indexed _depositor, uint256[] _collateralAmounts);
    event DepositSnapshotUpdated(address indexed _depositor, uint256 _P, uint256 _G);
    event RewardClaimed(address indexed account, address indexed recipient, uint256 claimed);

    event UserDepositChanged(address indexed _depositor, uint256 _newDeposit);
    event ClaimStartTimeSet(uint256 _startTime);
    event CollateralSunset(address indexed _collateralToken);
    event RewardRateUpdated(uint128 _newRate);

    // // function initialize(
    // //     ISatoshiCore _satoshiCore,
    // //     IDebtToken _debtToken,
    // //     IFactory _factory,
    // //     ILiquidationManager _liquidationManager,
    // //     ICommunityIssuance _communityIssuance
    // // ) external;

    // function claimCollateralGains(address recipient, uint256[] calldata collateralIndexes) external;

    // function enableCollateral(IERC20 _collateral) external;

    // function offset(IERC20 collateralToken, uint256 _debtToOffset, uint256 _collToAdd) external;

    // function provideToSP(uint256 _amount) external;

    // function startCollateralSunset(IERC20 collateralToken) external;

    // function withdrawFromSP(uint256 _amount) external;

    // function DECIMAL_PRECISION() external view returns (uint256);

    // function P() external view returns (uint256);

    // function SCALE_FACTOR() external view returns (uint256);

    // function SUNSET_DURATION() external view returns (uint128);

    // function SP_MAX_REWARD_RATE() external view returns (uint128);

    // function accountDeposits(address) external view returns (uint128 amount, uint128 timestamp);

    // function collateralGainsByDepositor(address depositor, uint256) external view returns (uint80 gains);

    // function collateralTokens(uint256) external view returns (IERC20);

    // function currentEpoch() external view returns (uint128);

    // function currentScale() external view returns (uint128);

    // function debtToken() external view returns (IDebtToken);

    // function depositSnapshots(address) external view returns (uint256 P, uint256 G, uint128 scale, uint128 epoch);

    // function depositSums(address, uint256) external view returns (uint256);

    // function epochToScaleToG(uint128, uint128) external view returns (uint256);

    // function epochToScaleToSums(uint128, uint128, uint256) external view returns (uint256);

    // function factory() external view returns (IFactory);

    // function getCompoundedDebtDeposit(address _depositor) external view returns (uint256);

    // function getDepositorCollateralGain(address _depositor) external view returns (uint256[] memory collateralGains);

    // function getTotalDebtTokenDeposits() external view returns (uint256);

    // function indexByCollateral(IERC20 collateral) external view returns (uint256 index);

    // function liquidationManager() external view returns (ILiquidationManager);

    // function communityIssuance() external view returns (ICommunityIssuance);

    // function claimableReward(address _depositor) external view returns (uint256);

    // function claimReward(address recipient) external returns (uint256 amount);

    // function setClaimStartTime(uint32 _startTime) external;

    // function isClaimStart() external view returns (bool);

    // function rewardRate() external view returns (uint128);

    // function setSPRewardRate(uint128 _newRewardRate) external;
}

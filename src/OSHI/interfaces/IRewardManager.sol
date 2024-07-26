// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "../../xapp/helpers/interfaces/IWETH.sol";
import {IDebtToken} from "../../xapp/interfaces/IDebtToken.sol";
import {IOSHIToken} from "./IOSHIToken.sol";
import {ITroveManager} from "../../xapp/interfaces/ITroveManager.sol";

enum LockDuration {
    THREE, // 3 months
    SIX, // 6 months
    NINE, // 9 months
    TWELVE // 12 months

}

uint256 constant NUMBER_OF_LOCK_DURATIONS = 4;

interface IRewardManager {
    event TroveManagerRegistered(ITroveManager);
    event TroveManagerRemoved(ITroveManager);
    event DebtTokenSet(IDebtToken);
    event WETHSet(IWETH);
    event TotalOSHIStakedUpdated(uint256);
    event StakeChanged(address, uint256);
    event StakingGainsWithdrawn(address, uint256[], uint256);
    event StakerSnapshotsUpdated(address, uint256[], uint256);
    event F_COLLUpdated(address, uint256);
    event F_SATUpdated(uint256);
    event WhitelistCallerSet(address, bool);
    event SatoshiXappSet(address);

    error NativeTokenTransferFailed();

    struct Snapshot {
        uint256[1000] F_COLL_Snapshot;
        uint256 F_SAT_Snapshot;
    }

    struct Stake {
        address staker;
        uint256 amount;
        LockDuration lockDuration;
        uint32 endTime;
    }

    struct StakeData {
        uint256 lockWeights;
        uint32[NUMBER_OF_LOCK_DURATIONS] nextUnlockIndex;
    }

    function initialize(address owner) external;
    function stake(uint256 _amount, LockDuration _duration) external;
    function unstake(uint256 _amount) external;
    function claimReward() external;
    function claimFee() external;
    function increaseCollPerUintStaked(uint256 _amount) external;
    function increaseSATPerUintStaked(uint256 _amount) external;
    function getPendingCollGain(address _user) external view returns (uint256[] memory);
    function getPendingSATGain(address _user) external view returns (uint256);
    function registerTroveManager(ITroveManager _troveManager) external;
    function removeTroveManager(ITroveManager _troveManager) external;
    function setAddresses(address _satoshiXPP, IWETH _weth, IDebtToken _debtToken, IOSHIToken _oshiToken) external;
    function F_SAT() external view returns (uint256);
    function F_COLL(uint256) external view returns (uint256);
    function collForFeeReceiver(uint256) external view returns (uint256);
    function satForFeeReceiver() external view returns (uint256);
    function debtToken() external view returns (IDebtToken);
    function oshiToken() external view returns (IOSHIToken);
    function collToken(uint256) external view returns (IERC20);
    function weth() external view returns (IWETH);
    function satoshiXApp() external view returns (address);
    function collTokenIndex(address _collToken) external view returns (uint256);
    function totalOSHIWeightedStaked() external view returns (uint256);
    function getAvailableUnstakeAmount(address _user) external view returns (uint256);
    function getSnapshot(address _user) external view returns (Snapshot memory);
    function getUserStakes(address _user, uint256 _index) external view returns (Stake[] memory);
    function getStakeData(address _user) external view returns (StakeData memory);
    function isTroveManagerRegistered(address) external view returns (bool);
    function setWhitelistCaller(address _caller, bool _status) external;
}

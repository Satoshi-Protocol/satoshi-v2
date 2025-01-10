// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/Test.sol";
import {AccessControlInternal} from "@solidstate/contracts/access/access_control/AccessControlInternal.sol";
import {OwnableInternal} from "@solidstate/contracts/access/ownable/OwnableInternal.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AppStorage} from "../AppStorage.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {IDebtToken} from "../interfaces/IDebtToken.sol";
import {ISortedTroves} from "../interfaces/ISortedTroves.sol";
import {IPriceFeed} from "../../priceFeed/IPriceFeed.sol";
import {DeploymentParams, IFactoryFacet} from "../interfaces/IFactoryFacet.sol";
import {ICommunityIssuance} from "../../OSHI/interfaces/ICommunityIssuance.sol";
import {TroveManagerData} from "../interfaces/IBorrowerOperationsFacet.sol";
import {Queue, SunsetIndex} from "../interfaces/IStabilityPoolFacet.sol";
import {Config} from "../Config.sol";

contract FactoryFacet is IFactoryFacet, AccessControlInternal {
    function troveManagerCount() external view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.troveManagers.length;
    }

    function troveManagers(uint256 index) external view returns (ITroveManager) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.troveManagers[index];
    }

    function maxTMRewardRate() external pure returns (uint128) {
        return Config.TM_MAX_REWARD_RATE;
    }

    function deployNewInstance(IERC20 collateralToken, IPriceFeed priceFeed, DeploymentParams calldata params)
        external
        onlyRole(Config.OWNER_ROLE)
        returns (ITroveManager troveManagerBeaconProxy, ISortedTroves sortedTrovesBeaconProxy)
    {
        AppStorage.Layout storage s = AppStorage.layout();
        sortedTrovesBeaconProxy = _deploySortedTrovesBeaconProxy(s);
        troveManagerBeaconProxy = _deployTroveManagerBeaconProxy(s);

        s.troveManagers.push(troveManagerBeaconProxy);

        sortedTrovesBeaconProxy.setConfig(troveManagerBeaconProxy);
        troveManagerBeaconProxy.setConfig(sortedTrovesBeaconProxy, collateralToken);

        // verify that the oracle is correctly working
        troveManagerBeaconProxy.fetchPrice();

        s.debtToken.enableTroveManager(troveManagerBeaconProxy);
        _enableCollateral(s, collateralToken);
        _configureCollateral(s, troveManagerBeaconProxy, collateralToken);
        _enableTroveManager(s, troveManagerBeaconProxy);

        troveManagerBeaconProxy.setParameters(
            params.minuteDecayFactor,
            params.redemptionFeeFloor,
            params.maxRedemptionFee,
            params.borrowingFeeFloor,
            params.maxBorrowingFee,
            params.interestRateInBps,
            params.maxDebt,
            params.MCR,
            params.rewardRate,
            params.claimStartTime
        );

        emit NewDeployment(collateralToken, priceFeed, troveManagerBeaconProxy, sortedTrovesBeaconProxy);

        return (troveManagerBeaconProxy, sortedTrovesBeaconProxy);
    }

    function _enableCollateral(AppStorage.Layout storage s, IERC20 _collateral) internal {
        uint256 length = s.collateralTokens.length;
        bool collateralEnabled;
        for (uint256 i = 0; i < length; i++) {
            if (s.collateralTokens[i] == _collateral) {
                collateralEnabled = true;
                break;
            }
        }
        if (!collateralEnabled) {
            Queue memory queueCached = s.queue;
            if (queueCached.nextSunsetIndexKey > queueCached.firstSunsetIndexKey) {
                SunsetIndex memory sIdx = s.sunsetIndexes[queueCached.firstSunsetIndexKey];
                if (sIdx.expiry < block.timestamp) {
                    delete s.sunsetIndexes[s.queue.firstSunsetIndexKey++];
                    _overwriteCollateral(s, _collateral, sIdx.idx);
                    return;
                }
            }
            s.collateralTokens.push(_collateral);
            s.indexByCollateral[_collateral] = s.collateralTokens.length;
        } else {
            // revert if the factory is trying to deploy a new TM with a sunset collateral
            require(s.indexByCollateral[_collateral] > 0, "Collateral is sunsetting");
        }
    }

    function _overwriteCollateral(AppStorage.Layout storage s, IERC20 _newCollateral, uint256 idx) internal {
        require(s.indexByCollateral[_newCollateral] == 0, "Collateral must be sunset");
        uint256 length = s.collateralTokens.length;
        require(idx < length, "Index too large");
        uint256 externalLoopEnd = s.currentEpoch;
        uint256 internalLoopEnd = s.currentScale;
        for (uint128 i; i <= externalLoopEnd;) {
            for (uint128 j; j <= internalLoopEnd;) {
                s.epochToScaleToSums[i][j][idx] = 0;
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
        s.indexByCollateral[_newCollateral] = idx + 1;
        emit CollateralOverwritten(s.collateralTokens[idx], _newCollateral);
        s.collateralTokens[idx] = _newCollateral;
    }

    function _configureCollateral(AppStorage.Layout storage s, ITroveManager troveManager, IERC20 collateralToken)
        internal
    {
        s.troveManagersData[troveManager] = TroveManagerData(collateralToken, uint16(s.troveManagers.length));
        s.troveManagers.push(troveManager);
        emit CollateralConfigured(troveManager, collateralToken);
    }

    function _enableTroveManager(AppStorage.Layout storage s, ITroveManager _troveManager) internal {
        s.enabledTroveManagers[_troveManager] = true;
    }

    function _deploySortedTrovesBeaconProxy(AppStorage.Layout storage s) internal returns (ISortedTroves) {
        bytes memory data = abi.encodeCall(ISortedTroves.initialize, msg.sender);
        return ISortedTroves(address(new BeaconProxy(address(s.sortedTrovesBeacon), data)));
    }

    function _deployTroveManagerBeaconProxy(AppStorage.Layout storage s) internal returns (ITroveManager) {
        bytes memory data = abi.encodeCall(
            ITroveManager.initialize, (msg.sender, s.gasPool, s.debtToken, s.communityIssuance, address(this))
        );
        return ITroveManager(address(new BeaconProxy(address(s.troveManagerBeacon), data)));
    }

    function setTMRewardRate(uint128[] calldata _numerator, uint128 _denominator)
        external
        onlyRole(Config.OWNER_ROLE)
    {
        AppStorage.Layout storage s = AppStorage.layout();
        // console.log("setTMRewardRate", _numerator.length, s.troveManagers.length);
        require(_numerator.length == s.troveManagers.length, "Factory: invalid length");
        uint128 totalRewardRate;
        for (uint256 i; i < _numerator.length; ++i) {
            uint128 troveRewardRate = _numerator[i] * Config.TM_MAX_REWARD_RATE / _denominator;
            totalRewardRate += troveRewardRate;
            s.troveManagers[i].setTMRewardRate(troveRewardRate);
        }
        require(totalRewardRate <= Config.TM_MAX_REWARD_RATE, "Factory: invalid total reward rate");
    }
}

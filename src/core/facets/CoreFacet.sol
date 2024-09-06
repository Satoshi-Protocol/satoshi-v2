// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {AccessControlInternal} from "@solidstate/contracts/access/access_control/AccessControlInternal.sol";
import {OwnableInternal} from "@solidstate/contracts/access/ownable/OwnableInternal.sol";
import {ICoreFacet} from "../interfaces/ICoreFacet.sol";
import {AppStorage} from "../AppStorage.sol";
import {IDebtToken} from "../interfaces/IDebtToken.sol";
import {IRewardManager} from "../../OSHI/interfaces/IRewardManager.sol";
import {ICommunityIssuance} from "../../OSHI/interfaces/ICommunityIssuance.sol";
import {Config} from "../Config.sol";

contract CoreFacet is ICoreFacet, AccessControlInternal, OwnableInternal {
    // constructor(address _owner, address _guardian, address _feeReceiver, address _rewardManager, uint256 _ownershipTransferDelay) {
    //     owner = _owner;
    //     startTime = block.timestamp;
    //     guardian = _guardian;
    //     feeReceiver = _feeReceiver;
    //     rewardManager = _rewardManager;
    //     ownershipTransferDelay = ownershipTransferDelay;
    //     emit GuardianSet(_guardian);
    //     emit FeeReceiverSet(_feeReceiver);
    //     emit RewardManagerSet(_rewardManager);
    // }

    /**
     * @notice Set the receiver of one time borrow fee in the protocol
     * @param _feeReceiver Address of the fee's recipient
     */
    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        AppStorage.Layout storage s = AppStorage.layout();
        s.feeReceiver = _feeReceiver;
        emit FeeReceiverSet(_feeReceiver);
    }

    /**
     * @notice Set the reward manager address
     * @param _rewardManager Reward manager address
     */
    function setRewardManager(address _rewardManager) external onlyOwner {
        AppStorage.Layout storage s = AppStorage.layout();
        s.rewardManager = IRewardManager(_rewardManager);
        emit RewardManagerSet(_rewardManager);
    }

    /**
     * @notice Sets the global pause state of the protocol
     *         Pausing is used to mitigate risks in exceptional circumstances
     *         Functionalities affected by pausing are:
     *         - New borrowing is not possible
     *         - New collateral deposits are not possible
     *         - New stability pool deposits are not possible
     * @param _paused If true the protocol is paused
     */
    function setPaused(bool _paused) external {
        AppStorage.Layout storage s = AppStorage.layout();
        require(
            (_paused && _hasRole(Config.GUARDIAN_ROLE, msg.sender)) || _hasRole(Config.OWNER_ROLE, msg.sender),
            "Unauthorized"
        );
        s.paused = _paused;
        if (_paused) {
            emit Paused();
        } else {
            emit Unpaused();
        }
    }

    function feeReceiver() external view returns (address) {
        return AppStorage.layout().feeReceiver;
    }

    function rewardManager() external view returns (IRewardManager) {
        return AppStorage.layout().rewardManager;
    }

    function paused() external view returns (bool) {
        return AppStorage.layout().paused;
    }

    function startTime() external view returns (uint256) {
        return AppStorage.layout().startTime;
    }

    function debtToken() external view returns (IDebtToken) {
        return AppStorage.layout().debtToken;
    }

    function sortedTrovesBeacon() external view returns (IBeacon) {
        return AppStorage.layout().sortedTrovesBeacon;
    }

    function troveManagerBeacon() external view returns (IBeacon) {
        return AppStorage.layout().troveManagerBeacon;
    }

    function communityIssuance() external view returns (ICommunityIssuance) {
        return AppStorage.layout().communityIssuance;
    }

    function gasCompensation() external pure returns (uint256) {
        return Config.DEBT_GAS_COMPENSATION;
    }
}

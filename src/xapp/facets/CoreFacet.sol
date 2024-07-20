// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICoreFacet} from "../interfaces/ICoreFacet.sol";
import {AppStorage} from "../storages/AppStorage.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";

contract CoreFacet is ICoreFacet, SatoshiOwnable {
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
     * @notice Set the guardian address
     *            The guardian can execute some emergency actions
     * @param _guardian Guardian address
     */
    function setGuardian(address _guardian) external onlyOwner {
        AppStorage.Layout storage s = AppStorage.layout();
        s.guardian = _guardian;
        emit GuardianSet(_guardian);
    }

    /**
     * @notice Set the reward manager address
     * @param _rewardManager Reward manager address
     */
    function setRewardManager(address _rewardManager) external onlyOwner {
        AppStorage.Layout storage s = AppStorage.layout();
        s.rewardManager = _rewardManager;
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
        require((_paused && msg.sender == s.guardian) || msg.sender == s.owner, "Unauthorized");
        s.paused = _paused;
        if (_paused) {
            emit Paused();
        } else {
            emit Unpaused();
        }
    }

    function setOwnershipTransferDelay(uint256 _ownershipTransferDelay) external onlyOwner {
        AppStorage.Layout storage s = AppStorage.layout();
        s.ownershipTransferDelay = _ownershipTransferDelay;
        emit OwnershipTransferDelay(_ownershipTransferDelay);
    }

    function commitTransferOwnership(address newOwner) external onlyOwner {
        AppStorage.Layout storage s = AppStorage.layout();
        s.pendingOwner = newOwner;
        s.ownershipTransferDeadline = block.timestamp + s.ownershipTransferDelay;

        emit NewOwnerCommitted(msg.sender, newOwner, block.timestamp + s.ownershipTransferDelay);
    }

    function acceptTransferOwnership() external {
        AppStorage.Layout storage s = AppStorage.layout();
        require(msg.sender == s.pendingOwner, "Only new owner");
        require(block.timestamp >= s.ownershipTransferDeadline, "Deadline not passed");

        emit NewOwnerAccepted(s.owner, msg.sender);

        s.owner = s.pendingOwner;
        s.pendingOwner = address(0);
        s.ownershipTransferDeadline = 0;
    }

    function revokeTransferOwnership() external onlyOwner {
        AppStorage.Layout storage s = AppStorage.layout();
        emit NewOwnerRevoked(msg.sender, s.pendingOwner);

        s.pendingOwner = address(0);
        s.ownershipTransferDeadline = 0;
    }

    function feeReceiver() external view returns (address) {
        return AppStorage.layout().feeReceiver;
    }

    function rewardManager() external view returns (address) {
        return AppStorage.layout().rewardManager;
    }

    function guardian() external view returns (address) {
        return AppStorage.layout().guardian;
    }

    function owner() external view returns (address) {
        return AppStorage.layout().owner;
    }

    function ownershipTransferDelay() external view returns (uint256) {
        return AppStorage.layout().ownershipTransferDelay;
    }

    function ownershipTransferDeadline() external view returns (uint256) {
        return AppStorage.layout().ownershipTransferDeadline;
    }

    function paused() external view returns (bool) {
        return AppStorage.layout().paused;
    }

    function pendingOwner() external view returns (address) {
        return AppStorage.layout().pendingOwner;
    }

    function startTime() external view returns (uint256) {
        return AppStorage.layout().startTime;
    }
}

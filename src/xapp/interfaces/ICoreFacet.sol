// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRewardManager} from "../../OSHI/interfaces/IRewardManager.sol";

interface ICoreFacet {
    event RewardManagerSet(address rewardManager);
    event FeeReceiverSet(address feeReceiver);
    event GuardianSet(address guardian);
    event Paused();
    event Unpaused();

    function setFeeReceiver(address _feeReceiver) external;

    function setRewardManager(address _rewardManager) external;

    function setPaused(bool _paused) external;

    function feeReceiver() external view returns (address);

    function rewardManager() external view returns (IRewardManager);

    function paused() external view returns (bool);

    function startTime() external view returns (uint256);
}

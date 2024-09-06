// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {IRewardManager} from "../../OSHI/interfaces/IRewardManager.sol";
import {IDebtToken} from "./IDebtToken.sol";
import {ICommunityIssuance} from "../../OSHI/interfaces/ICommunityIssuance.sol";

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

    function debtToken() external view returns (IDebtToken);

    function gasCompensation() external view returns (uint256);

    function sortedTrovesBeacon() external view returns (IBeacon);

    function troveManagerBeacon() external view returns (IBeacon);

    function communityIssuance() external view returns (ICommunityIssuance);
}

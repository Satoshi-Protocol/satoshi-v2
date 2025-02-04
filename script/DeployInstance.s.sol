// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ICommunityIssuance } from "../src/OSHI/interfaces/ICommunityIssuance.sol";
import { IRewardManager } from "../src/OSHI/interfaces/IRewardManager.sol";
import { DeploymentParams, IFactoryFacet } from "../src/core/facets/FactoryFacet.sol";

import { ICoreFacet } from "../src/core/interfaces/ICoreFacet.sol";
import { IDebtToken } from "../src/core/interfaces/IDebtToken.sol";
import { IPriceFeedAggregatorFacet } from "../src/core/interfaces/IPriceFeedAggregatorFacet.sol";
import { ISortedTroves } from "../src/core/interfaces/ISortedTroves.sol";
import { ITroveManager } from "../src/core/interfaces/ITroveManager.sol";
import { IPriceFeed } from "../src/priceFeed/interfaces/IPriceFeed.sol";

import {
    BORROWING_FEE_FLOOR,
    COLLATERAL_ADDRESS,
    INTEREST_RATE_IN_BPS,
    MAX_BORROWING_FEE,
    MAX_DEBT,
    MAX_REDEMPTION_FEE,
    MCR,
    MINUTE_DECAY_FACTOR,
    PRICE_FEED_ADDRESS,
    REDEMPTION_FEE_FLOOR,
    REWARD_MANAGER_ADDRESS,
    REWARD_RATE,
    SATOSHI_X_APP_ADDRESS,
    TM_ALLOCATION,
    TM_CLAIM_START_TIME
} from "./DeployInstanceConfig.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeployInstanceScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    address internal satoshiXApp;
    IERC20 internal collateral;
    IPriceFeed internal priceFeed;
    IRewardManager internal rewardManager;
    ICommunityIssuance internal communityIssuance;
    IDebtToken internal debtToken;
    DeploymentParams internal deploymentParams;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        collateral = IERC20(COLLATERAL_ADDRESS);
        priceFeed = IPriceFeed(PRICE_FEED_ADDRESS);
        satoshiXApp = SATOSHI_X_APP_ADDRESS;
        communityIssuance = ICoreFacet(satoshiXApp).communityIssuance();
        assert(address(communityIssuance) != address(0));
        debtToken = ICoreFacet(satoshiXApp).debtToken();
        assert(address(debtToken) != address(0));
        rewardManager = IRewardManager(REWARD_MANAGER_ADDRESS);
        assert(address(rewardManager) != address(0));
        deploymentParams = DeploymentParams({
            minuteDecayFactor: MINUTE_DECAY_FACTOR,
            redemptionFeeFloor: REDEMPTION_FEE_FLOOR,
            maxRedemptionFee: MAX_REDEMPTION_FEE,
            borrowingFeeFloor: BORROWING_FEE_FLOOR,
            maxBorrowingFee: MAX_BORROWING_FEE,
            interestRateInBps: INTEREST_RATE_IN_BPS,
            maxDebt: MAX_DEBT,
            MCR: MCR,
            rewardRate: REWARD_RATE,
            OSHIAllocation: TM_ALLOCATION,
            claimStartTime: TM_CLAIM_START_TIME
        });
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        IPriceFeedAggregatorFacet(satoshiXApp).setPriceFeed(collateral, priceFeed);
        DeploymentParams memory params = deploymentParams;
        (ITroveManager troveManagerBeaconProxy, ISortedTroves sortedTrovesBeaconProxy) =
            IFactoryFacet(satoshiXApp).deployNewInstance(collateral, priceFeed, params);

        // set reward manager settings
        rewardManager.registerTroveManager(troveManagerBeaconProxy);

        // set community issuance allocation & addresses
        _setCommunityIssuanceAllocation(address(troveManagerBeaconProxy), params.OSHIAllocation);
        require(communityIssuance.allocated(address(troveManagerBeaconProxy)) == params.OSHIAllocation);

        console.log("SortedTrovesBeaconProxy: address:", address(sortedTrovesBeaconProxy));
        console.log("TroveManagerBeaconProxy: address:", address(troveManagerBeaconProxy));

        vm.stopBroadcast();
    }

    function _setCommunityIssuanceAllocation(address troveManagerBeaconProxy, uint256 allocation) internal {
        address[] memory _recipients = new address[](1);
        _recipients[0] = troveManagerBeaconProxy;
        uint256[] memory _amount = new uint256[](1);
        _amount[0] = allocation;
        communityIssuance.setAllocated(_recipients, _amount);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {DeployBase} from "./utils/DeployBase.t.sol";
import {Test} from "forge-std/Test.sol";
import {EndpointV2Mock} from "@layerzerolabs/test-devtools-evm-foundry/contracts/mocks/EndpointV2Mock.sol";

import {ICoreFacet} from "../src/core/interfaces/ICoreFacet.sol";
import {InitialConfig} from "../src/core/InitialConfig.sol";
import {Config} from "../src/core/Config.sol";
import {DEPLOYER, OWNER} from "./TestConfig.sol";

contract CoreFacetTest is DeployBase {
    address owner = InitialConfig.OWNER;

    function setUp() public virtual override {
        super.setUp();
        _satoshiXAppInit(DEPLOYER);
    }

    function test_feeReceiver() public {
        address feeReceiver = ICoreFacet(address(satoshiXApp)).feeReceiver();
        assertEq(feeReceiver, InitialConfig.FEE_RECEIVER);
    }

    function test_setFeeReceiver() public {
        address newFeeReceiver = address(0x123);

        vm.prank(owner);
        ICoreFacet(address(satoshiXApp)).setFeeReceiver(newFeeReceiver);
        assertEq(ICoreFacet(address(satoshiXApp)).feeReceiver(), newFeeReceiver);
    }

    function test_setRewardManager() public {
        address newRewardManager = address(0x456);

        vm.prank(owner);
        ICoreFacet(address(satoshiXApp)).setRewardManager(newRewardManager);
        assertEq(address(ICoreFacet(address(satoshiXApp)).rewardManager()), newRewardManager);
    }

    function test_setPaused() public {
        vm.prank(owner);
        ICoreFacet(address(satoshiXApp)).setPaused(true);
        assertTrue(ICoreFacet(address(satoshiXApp)).paused());

        vm.prank(owner);
        ICoreFacet(address(satoshiXApp)).setPaused(false);
        assertFalse(ICoreFacet(address(satoshiXApp)).paused());
    }

    // function test_startTime() public {
    //     uint256 startTime = ICoreFacet(address(satoshiXApp)).startTime();
    //     assertEq(startTime, 0);
    // }

    function test_debtToken() public {
        address _debtToken = address(ICoreFacet(address(satoshiXApp)).debtToken());
        assertEq(_debtToken, address(debtToken));
    }

    function test_sortedTrovesBeacon() public {
        address _sortedTrovesBeacon = address(ICoreFacet(address(satoshiXApp)).sortedTrovesBeacon());
        assertEq(_sortedTrovesBeacon, address(sortedTrovesBeacon));
    }

    function test_troveManagerBeacon() public {
        address _troveManagerBeacon = address(ICoreFacet(address(satoshiXApp)).troveManagerBeacon());
        assertEq(_troveManagerBeacon, address(troveManagerBeacon));
    }

    function test_communityIssuance() public {
        address _communityIssuance = address(ICoreFacet(address(satoshiXApp)).communityIssuance());
        assertEq(_communityIssuance, address(communityIssuance));
    }

    function test_gasCompensation() public {
        uint256 gasCompensation = ICoreFacet(address(satoshiXApp)).gasCompensation();
        assertEq(gasCompensation, Config.DEBT_GAS_COMPENSATION);
    }
}

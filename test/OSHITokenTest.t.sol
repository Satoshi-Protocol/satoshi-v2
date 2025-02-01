// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TestConfig.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DeployBase, LocalVars} from "./utils/DeployBase.t.sol";
import {SatoshiMath} from "../src/library/SatoshiMath.sol";
import {SatoshiXApp} from "../src/core/SatoshiXApp.sol";
import {ISatoshiXApp} from "../src/core/interfaces/ISatoshiXApp.sol";
import {BorrowerOperationsFacet} from "../src/core/facets/BorrowerOperationsFacet.sol";
import {IBorrowerOperationsFacet} from "../src/core/interfaces/IBorrowerOperationsFacet.sol";
import {CoreFacet} from "../src/core/facets/CoreFacet.sol";
import {ICoreFacet} from "../src/core/interfaces/ICoreFacet.sol";
import {ITroveManager, TroveManagerOperation} from "../src/core/interfaces/ITroveManager.sol";
import {FactoryFacet} from "../src/core/facets/FactoryFacet.sol";
import {IFactoryFacet, DeploymentParams} from "../src/core/interfaces/IFactoryFacet.sol";
import {LiquidationFacet} from "../src/core/facets/LiquidationFacet.sol";
import {ILiquidationFacet} from "../src/core/interfaces/ILiquidationFacet.sol";
import {PriceFeedAggregatorFacet} from "../src/core/facets/PriceFeedAggregatorFacet.sol";
import {IPriceFeedAggregatorFacet} from "../src/core/interfaces/IPriceFeedAggregatorFacet.sol";
import {StabilityPoolFacet} from "../src/core/facets/StabilityPoolFacet.sol";
import {IStabilityPoolFacet} from "../src/core/interfaces/IStabilityPoolFacet.sol";
import {INexusYieldManagerFacet} from "../src/core/interfaces/INexusYieldManagerFacet.sol";
import {NexusYieldManagerFacet} from "../src/core/facets/NexusYieldManagerFacet.sol";
import {Initializer} from "../src/core/Initializer.sol";
import {IRewardManager} from "../src/OSHI/interfaces/IRewardManager.sol";
import {RewardManager} from "../src/OSHI/RewardManager.sol";
import {IDebtToken} from "../src/core/interfaces/IDebtToken.sol";
import {DebtToken} from "../src/core/DebtToken.sol";
import {ICommunityIssuance} from "../src/OSHI/interfaces/ICommunityIssuance.sol";
import {CommunityIssuance} from "../src/OSHI/CommunityIssuance.sol";
import {SortedTroves} from "../src/core/SortedTroves.sol";
import {TroveManager} from "../src/core/TroveManager.sol";
import {ISortedTroves} from "../src/core/interfaces/ISortedTroves.sol";
import {IPriceFeed} from "../src/priceFeed/interfaces/IPriceFeed.sol";
import {AggregatorV3Interface} from "../src/priceFeed/interfaces/AggregatorV3Interface.sol";
import {IOSHIToken} from "../src/OSHI/interfaces/IOSHIToken.sol";
import {OSHIToken} from "../src/OSHI/OSHIToken.sol";
import {ISatoshiPeriphery, LzSendParam} from "../src/core/helpers/interfaces/ISatoshiPeriphery.sol";
import {SatoshiPeriphery} from "../src/core/helpers/SatoshiPeriphery.sol";
import {IMultiCollateralHintHelpers} from "../src/core/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {RoundData, OracleMock} from "./mocks/OracleMock.sol";
import {HintLib} from "./utils/HintLib.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract OSHITokenTest is DeployBase, TroveBase {
    using Math for uint256;

    bytes32 private immutable _PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    uint256 maxFeePercentage = 0.05e18; // 5%
    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    address user;
    address user1;
    address user2;
    address user3;
    address user4;
    ERC20Mock collateral;

    struct LiquidationVars {
        uint256 entireTroveDebt;
        uint256 entireTroveColl;
        uint256 collGasCompensation;
        uint256 debtGasCompensation;
        uint256 debtToOffset;
        uint256 collToSendToSP;
        uint256 debtToRedistribute;
        uint256 collToRedistribute;
        uint256 collSurplus;
        // user state
        uint256[5] userCollBefore;
        uint256[5] userCollAfter;
        uint256[5] userDebtBefore;
        uint256[5] userDebtAfter;
    }

    function setUp() public override {
        super.setUp();
        // testing user
        user = vm.addr(5);
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);
        user4 = vm.addr(4);

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deployMockTroveManager(DEPLOYER);
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));
        collateral = ERC20Mock(address(collateralMock));

        vm.startPrank(OWNER);
        // mint some tokens
        oshiToken.mint(user1, 150);
        oshiToken.mint(user2, 100);
        oshiToken.mint(user3, 50);

        vm.stopPrank();
    }

    function testGetsBalanceOfUser() public {
        assertEq(oshiToken.balanceOf(user1), 150);
        assertEq(oshiToken.balanceOf(user2), 100);
        assertEq(oshiToken.balanceOf(user3), 50);
    }

    function testGetsTotalSupply() public {
        assertEq(oshiToken.totalSupply(), 300);
    }

    function testTokenName() public {
        assertEq(oshiToken.name(), "OSHI");
    }

    function testSymbol() public {
        assertEq(oshiToken.symbol(), "OSHI");
    }

    function testDecimals() public {
        assertEq(oshiToken.decimals(), 18);
    }

    function testAllowance() public {
        vm.startPrank(user1);
        oshiToken.approve(user2, 100);
        vm.stopPrank();

        uint256 allowance1 = oshiToken.allowance(user1, user2);
        uint256 allowance2 = oshiToken.allowance(user1, user3);

        assertEq(allowance1, 100);
        assertEq(allowance2, 0);
    }

    function testTransfer() public {
        vm.prank(user1);
        oshiToken.transfer(user2, 50);
        assertEq(oshiToken.balanceOf(user1), 100);
        assertEq(oshiToken.balanceOf(user2), 150);
    }

    function testTransferFrom() public {
        assertEq(oshiToken.allowance(user1, user2), 0);

        vm.prank(user1);
        oshiToken.approve(user2, 50);
        assertEq(oshiToken.allowance(user1, user2), 50);

        vm.prank(user2);
        assertTrue(oshiToken.transferFrom(user1, user3, 50));
        assertEq(oshiToken.balanceOf(user3), 100);
        assertEq(oshiToken.balanceOf(user1), 150 - 50);

        vm.expectRevert();
        oshiToken.transferFrom(user1, user3, 50);
    }

    function testFailApproveToZeroAddress() public {
        oshiToken.approve(address(0), 1e18);
    }

    function testFailTransferToZeroAddress() public {
        vm.prank(user1);
        oshiToken.transfer(address(0), 10);
    }

    function testFailTransferInsufficientBalance() public {
        vm.prank(user1);
        oshiToken.transfer(user2, 3e18);
    }

    function testFailTransferFromInsufficientApprove() public {
        vm.prank(user1);
        oshiToken.approve(address(this), 10);
        oshiToken.transferFrom(user1, user2, 20);
    }

    function testPermit() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        vm.prank(OWNER);
        oshiToken.mint(owner, 100);

        uint256 nonce = IERC20Permit(address(oshiToken)).nonces(owner);
        uint256 deadline = block.timestamp + 1000;
        uint256 amount = 100;

        bytes32 digest = getDigest(owner, user2, amount, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        IERC20Permit(address(oshiToken)).permit(owner, user2, amount, deadline, v, r, s);

        assertEq(oshiToken.allowance(owner, user2), amount);
    }

    function testBurnToken() public {
        vm.startPrank(OWNER);
        oshiToken.mint(user1, 150);
        oshiToken.burn(user1, 150);
        assertEq(oshiToken.balanceOf(user1), 150);
        assertEq(oshiToken.totalSupply(), 300);
        vm.stopPrank();
    }

    /**
     * utils
     */
    function getDigest(address owner, address spender, uint256 amount, uint256 nonce, uint256 deadline)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                uint16(0x1901),
                IERC20Permit(address(oshiToken)).DOMAIN_SEPARATOR(),
                keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, amount, nonce, deadline))
            )
        );
    }

    function _openTrove(address caller, uint256 collateralAmt, uint256 debtAmt) internal {
        TroveBase.openTrove(
            borrowerOperationsProxy(),
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            DEBT_GAS_COMPENSATION,
            caller,
            caller,
            collateralMock,
            collateralAmt,
            debtAmt,
            0.05e18
        );
    }

    function _provideToSP(address caller, uint256 amount) internal {
        TroveBase.provideToSP(stabilityPoolProxy(), caller, amount);
    }

    function _withdrawFromSP(address caller, uint256 amount) internal {
        TroveBase.withdrawFromSP(stabilityPoolProxy(), caller, amount);
    }

    function _updateRoundData(RoundData memory data) internal {
        TroveBase.updateRoundData(oracleMockAddr, DEPLOYER, data);
    }

    function _claimCollateralGains(address caller) internal {
        vm.startPrank(caller);
        uint256[] memory collateralIndexes = new uint256[](1);
        collateralIndexes[0] = 0;
        stabilityPoolProxy().claimCollateralGains(caller, collateralIndexes);
        vm.stopPrank();
    }
}

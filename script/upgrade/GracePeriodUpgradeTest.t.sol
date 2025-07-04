// test/upgrade/GracePeriodUpgradeTest.t.sol

import { UpgradeGracePeriodLib } from "../../script/upgrade/UpgradeGracePeriod.s.sol";
import { TroveManager } from "../../src/core/TroveManager.sol";
import { ISatoshiPeriphery, LzSendParam } from "../../src/core/helpers/interfaces/ISatoshiPeriphery.sol";
import { IBorrowerOperationsFacet } from "../../src/core/interfaces/IBorrowerOperationsFacet.sol";
import { ILiquidationFacet } from "../../src/core/interfaces/ILiquidationFacet.sol";
import { IPriceFeedAggregatorFacet } from "../../src/core/interfaces/IPriceFeedAggregatorFacet.sol";
import { ITroveManager } from "../../src/core/interfaces/ITroveManager.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

interface IBeacon {
    function upgradeTo(address newImplementation) external;
    function implementation() external view returns (address);
}

contract GracePeriodUpgradeTest is Test {
    // Base network
    address payable constant SATOSHI_X_APP_ADDRESS = payable(0x9a3c724ee9603A7550499bE73DC743B371811dd3);
    address payable constant OWNER_ADDRESS = payable(0xd3e87B4B76E6F8bFf454AAFc2AD3271C5b317d47);
    address payable constant TM_BEACON_ADDRESS = payable(0xefAa8B485355066fA0993A605466eEf0ec026860);
    IERC20 constant WETH = IERC20(0x4200000000000000000000000000000000000006);
    ISatoshiPeriphery constant SATOSHI_PERIPHERY = ISatoshiPeriphery(0x9d9f0D9a13d3bA201003DD2e8950059d2c08D782);
    ITroveManager constant TROVE_MANAGER = ITroveManager(0xddac7d4e228c205197FE9961865FFE20173dE56B);

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_URL_BASE"), 31_529_675);
    }

    function beforeTestSetup(bytes4 testSelector) public returns (bytes[] memory beforeTestCalldata) {
        if (
            testSelector == this.testFork_NormalLiquidationAfterUpgrade.selector
                || testSelector == this.testFork_SetGracePeriod.selector
                || testSelector == this.testFork_SyncGracePeriod.selector
        ) {
            beforeTestCalldata = new bytes[](1);
            beforeTestCalldata[0] = abi.encodeWithSelector(this.testFork_UpgradeGracePeriod.selector);
        }
    }

    function testFork_UpgradeGracePeriod() public {
        vm.startPrank(OWNER_ADDRESS);

        UpgradeGracePeriodLib.upgradeGracePeriod(SATOSHI_X_APP_ADDRESS);
        IBeacon troveManagerBeacon = IBeacon(TM_BEACON_ADDRESS);
        address newTroveManagerImpl = address(new TroveManager());
        troveManagerBeacon.upgradeTo(address(newTroveManagerImpl));
    }

    function testFork_NormalLiquidationAfterUpgrade() public {
        address user = makeAddr("user");
        deal(address(WETH), user, 1000 ether);

        vm.startPrank(user);

        LzSendParam memory sendParam;
        IBorrowerOperationsFacet(SATOSHI_X_APP_ADDRESS).setDelegateApproval(address(SATOSHI_PERIPHERY), true);
        WETH.approve(address(SATOSHI_PERIPHERY), 1000 ether);
        SATOSHI_PERIPHERY.openTrove(TROVE_MANAGER, 1e18, 1 ether, 2000e18, address(0), address(0), sendParam);

        // ICR < MCR
        vm.mockCall(
            address(SATOSHI_X_APP_ADDRESS),
            abi.encodeWithSelector(IPriceFeedAggregatorFacet.fetchPrice.selector, address(WETH)),
            abi.encode(2200e18)
        );

        ILiquidationFacet(SATOSHI_X_APP_ADDRESS).liquidate(TROVE_MANAGER, user);
    }

    function testFork_SetGracePeriod() public {
        vm.startPrank(OWNER_ADDRESS);

        ILiquidationFacet(SATOSHI_X_APP_ADDRESS).setGracePeriod(15 minutes);
    }

    function testFork_SyncGracePeriod() public {
        IBorrowerOperationsFacet(SATOSHI_X_APP_ADDRESS).syncGracePeriod();
    }
}

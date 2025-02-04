// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";

// DevTools imports
import {IDebtToken} from "../src/core/interfaces/IDebtToken.sol";
import {ITroveManager} from "../src/core/interfaces/ITroveManager.sol";
import {ICoreFacet} from "../src/core/interfaces/ICoreFacet.sol";
import {FlashloanTester} from "../src/test/FlashloanTester.sol";
import {DebtTokenWithLz} from "../src/core/DebtTokenWithLz.sol";
import {Config} from "../src/core/Config.sol";
import {DEBT_GAS_COMPENSATION} from "./TestConfig.sol";

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IOFT, SendParam, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract LzDebtTokenTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    string constant DEBT_TOKEN_NAME = "SATOSHI_STABLECOIN";
    string constant DEBT_TOKEN_SYMBOL = "satUSD";

    address satoshiXApp = address(0x1);
    address owner = address(this);
    address userA = address(0x3);
    address userB = address(0x4);
    address troveManager = address(0x5);

    IDebtToken debtTokenA;
    IDebtToken debtTokenB;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    function setUp() public virtual override {
        vm.deal(userA, 1000 ether);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        address debtTokenImplA = address(new DebtTokenWithLz(endpoints[aEid]));
        bytes memory dataA = abi.encodeCall(
            IDebtToken.initialize,
            (DEBT_TOKEN_NAME, DEBT_TOKEN_SYMBOL, address(satoshiXApp), satoshiXApp, owner, DEBT_GAS_COMPENSATION)
        );
        debtTokenA = IDebtToken(address(new ERC1967Proxy(debtTokenImplA, dataA)));

        address debtTokenImplB = address(new DebtTokenWithLz(endpoints[bEid]));
        bytes memory dataB = abi.encodeCall(
            IDebtToken.initialize,
            (DEBT_TOKEN_NAME, DEBT_TOKEN_SYMBOL, address(satoshiXApp), satoshiXApp, owner, DEBT_GAS_COMPENSATION)
        );
        debtTokenB = IDebtToken(address(new ERC1967Proxy(debtTokenImplB, dataB)));

        address[] memory ofts = new address[](2);
        ofts[0] = address(debtTokenA);
        ofts[1] = address(debtTokenB);
        this.wireOApps(ofts);

        // mint tokens
        vm.startPrank(satoshiXApp);
        debtTokenA.mint(userA, 10 ether);
        debtTokenB.mint(userB, 10 ether);
        vm.stopPrank();
    }

    function test_send() external {
        IOFT _debtTokenA = IOFT(address(debtTokenA));
        uint256 tokensToSend = 1 ether;
        uint256 beforeUserADebtA = debtTokenA.balanceOf(userA);
        uint256 beforeUserBDebtB = debtTokenB.balanceOf(userB);

        // Quote send to get fee
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam =
            SendParam(bEid, addressToBytes32(userB), tokensToSend, tokensToSend, options, "", "");
        MessagingFee memory fee = _debtTokenA.quoteSend(sendParam, false);

        vm.expectEmit(false, true, false, false);
        emit IOFT.OFTSent(bytes32(0), 0, userA, tokensToSend, tokensToSend);
        vm.prank(userA);
        (, OFTReceipt memory oftReceipt) =
            _debtTokenA.send{value: fee.nativeFee}(sendParam, fee, payable(address(this)));
        verifyPackets(bEid, addressToBytes32(address(debtTokenB))); // Manually trigger `lzReceive`

        uint256 afterUserADebtA = debtTokenA.balanceOf(userA);
        uint256 afterUserBDebtB = debtTokenB.balanceOf(userB);
        assertEq(afterUserADebtA, beforeUserADebtA - oftReceipt.amountSentLD, "UserA should have send tokens");
        assertEq(afterUserBDebtB, beforeUserBDebtB + oftReceipt.amountReceivedLD, "UserB should have received tokens");
    }

    function test_enableTroveManager() external {
        address mockTroveManager = address(0x1234);

        vm.prank(satoshiXApp);
        debtTokenA.enableTroveManager(ITroveManager(mockTroveManager));

        assertEq(debtTokenA.troveManager(ITroveManager(mockTroveManager)), true);
    }

    function test_mintWithGasCompensation() external {
        uint256 amount = 10 ether;
        uint256 beforeUserAmount = debtTokenA.balanceOf(userA);
        uint256 beforeAppAmount = debtTokenA.balanceOf(satoshiXApp);

        vm.prank(satoshiXApp);
        debtTokenA.mintWithGasCompensation(userA, amount);

        uint256 afterUserAmount = debtTokenA.balanceOf(userA);
        uint256 afterAppAmount = debtTokenA.balanceOf(satoshiXApp);
        assertEq(amount, afterUserAmount - beforeUserAmount);
        assertEq(DEBT_GAS_COMPENSATION, afterAppAmount - beforeAppAmount);
    }

    function test_burnWithGasCompensation() external {
        uint256 amount = 10 ether;
        deal(address(debtTokenA), userA, amount);
        deal(address(debtTokenA), satoshiXApp, DEBT_GAS_COMPENSATION);
        uint256 beforeUserAmount = debtTokenA.balanceOf(userA);
        uint256 beforeAppAmount = debtTokenA.balanceOf(satoshiXApp);

        vm.prank(satoshiXApp);
        debtTokenA.burnWithGasCompensation(userA, amount);

        uint256 afterUserAmount = debtTokenA.balanceOf(userA);
        uint256 afterAppAmount = debtTokenA.balanceOf(satoshiXApp);
        assertEq(amount, beforeUserAmount - afterUserAmount);
        assertEq(DEBT_GAS_COMPENSATION, beforeAppAmount - afterAppAmount);
    }

    function test_burn() external {
        uint256 amount = 1 ether;
        uint256 beforeUserAmount = debtTokenA.balanceOf(userA);

        vm.prank(satoshiXApp);
        debtTokenA.enableTroveManager(ITroveManager(troveManager));

        vm.prank(troveManager);
        debtTokenA.burn(userA, amount);

        uint256 afterUserAmount = debtTokenA.balanceOf(userA);
        assertEq(amount, beforeUserAmount - afterUserAmount);
    }

    function test_sendToXApp() external {
        uint256 amount = 10 ether;
        uint256 beforeUserAmount = debtTokenA.balanceOf(userA);

        vm.prank(satoshiXApp);
        debtTokenA.sendToXApp(userA, amount);

        uint256 afterUserAmount = debtTokenA.balanceOf(userA);
        assertEq(amount, beforeUserAmount - afterUserAmount);
    }

    // Test the `rely` function
    function test_rely() external {
        address newWard = address(0x5);

        vm.prank(owner);
        debtTokenA.rely(newWard);

        assertEq(debtTokenA.wards(newWard), true, "New ward should be authorized");
    }

    // Test the `deny` function
    function test_deny() external {
        address newWard = address(0x5);

        vm.prank(owner);
        debtTokenA.rely(newWard);
        vm.prank(owner);
        debtTokenA.deny(newWard);

        assertEq(debtTokenA.wards(newWard), false, "Ward should be unauthorized");
    }

    // Test the `returnFromPool` function
    function test_returnFromPool() external {
        uint256 amount = 1 ether;
        address poolAddress = address(0x6);
        address receiver = address(0x7);

        deal(address(debtTokenA), poolAddress, amount);
        uint256 beforePoolBalance = debtTokenA.balanceOf(poolAddress);
        uint256 beforeReceiverBalance = debtTokenA.balanceOf(receiver);

        vm.prank(satoshiXApp);
        debtTokenA.returnFromPool(poolAddress, receiver, amount);

        uint256 afterPoolBalance = debtTokenA.balanceOf(poolAddress);
        uint256 afterReceiverBalance = debtTokenA.balanceOf(receiver);
        assertEq(beforePoolBalance - amount, afterPoolBalance, "Pool balance should decrease by the amount");
        assertEq(beforeReceiverBalance + amount, afterReceiverBalance, "Receiver balance should increase by the amount");
    }

    // Test the `transfer` function
    function test_transfer() external {
        uint256 amount = 1 ether;
        uint256 beforeUserBAmount = debtTokenA.balanceOf(userB);

        vm.prank(userA);
        debtTokenA.transfer(userB, amount);

        uint256 afterUserBAmount = debtTokenA.balanceOf(userB);
        assertEq(amount, afterUserBAmount - beforeUserBAmount, "Transferred amount should be correct");
    }

    // Test the `transferFrom` function
    function test_transferFrom() external {
        uint256 amount = 1 ether;
        uint256 beforeUserBAmount = debtTokenA.balanceOf(userB);

        vm.prank(userA);
        debtTokenA.approve(userB, amount);
        vm.prank(userB);
        debtTokenA.transferFrom(userA, userB, amount);

        uint256 afterUserBAmount = debtTokenA.balanceOf(userB);
        assertEq(amount, afterUserBAmount - beforeUserBAmount, "Transferred amount should be correct");
    }

    // Test the `DEBT_GAS_COMPENSATION` function
    function test_DEBT_GAS_COMPENSATION() external {
        uint256 compensation = debtTokenA.DEBT_GAS_COMPENSATION();
        assertEq(compensation, DEBT_GAS_COMPENSATION, "Gas compensation should match config");
    }

    function test_maxFlashLoan() external {
        address mockToken = vm.addr(0x1234);

        uint256 tokenMaxFlashLoan = debtTokenA.maxFlashLoan(mockToken);
        uint256 debtMaxFlashLoan = debtTokenA.maxFlashLoan(address(debtTokenA));

        assertEq(tokenMaxFlashLoan, 0, "Max flash loan should match config");
        assertEq(debtMaxFlashLoan, type(uint256).max - debtTokenA.totalSupply());
    }

    function test_flashFee() external {
        address mockToken = vm.addr(0x1234);
        uint256 amount = 1 ether;

        uint256 tokenFlashFee = debtTokenA.flashFee(mockToken, amount);
        uint256 debtFlashFee = debtTokenA.flashFee(address(debtTokenA), amount);

        assertEq(tokenFlashFee, 0, "Flash fee should match config");
        assertEq(debtFlashFee, (amount * debtTokenA.FLASH_LOAN_FEE()) / 10000, "Flash fee should match config");
    }

    /// ---- FAIL TESTS ---- ///

    // Test the `mint` function without authorization
    function test_FailIf_MintUnauthorized() external {
        uint256 amount = 10 ether;
        vm.expectRevert("Debt: Caller not SatoshiXapp/TM/auth");
        debtTokenA.mint(userA, amount);
    }

    // Test the `burn` function without authorization
    function test_FailIf_BurnUnauthorized() external {
        uint256 amount = 1 ether;

        vm.expectRevert("Debt: Caller not TroveManager or auth");
        debtTokenA.burn(userA, amount);
    }

    // Test the `_requireValidRecipient` function indirectly through transfers
    function test_FailIf_transferInvalidRecipient() external {
        uint256 amount = 1 ether;

        vm.expectRevert("Debt: Cannot transfer tokens directly to the Debt token contract or the zero address");
        debtTokenA.transfer(address(0), amount);
    }
}

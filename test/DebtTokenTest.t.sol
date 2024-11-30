// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Vm.sol";
import {Test, console} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {stdJson} from "forge-std/StdJson.sol";
import {DeployBase} from "./utils/DeployBase.t.sol";
import {DEPLOYER, OWNER, DEBT_TOKEN_NAME, DEBT_TOKEN_SYMBOL} from "./TestConfig.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {FlashloanTester} from "../src/test/FlashloanTester.sol";

contract DebtTokenTest is DeployBase {
        using Math for uint256;

    address user1;
    address user2;
    address user3;
    address user4;
    uint256 maxFeePercentage = 0.05e18; // 5%
    bytes32 private immutable _PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;


    function setUp() public override {
        super.setUp();
        // testing user
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);
        user4 = vm.addr(4);

        vm.startPrank(address(satoshiXApp));
        debtToken.mint(user1, 150);
        debtToken.mint(user2, 100);
        debtToken.mint(user3, 50);
        vm.stopPrank();
    }

    function test_deploy() public {
        assertContractAddressHasCode(address(debtToken));
    }

    function testGetsBalanceOfUser() public {
        assertEq(debtToken.balanceOf(user1), 150);
        assertEq(debtToken.balanceOf(user2), 100);
        assertEq(debtToken.balanceOf(user3), 50);
    }

    function testGetsTotalSupply() public {
        assertEq(debtToken.totalSupply(), 300);
    }

    function testTokenName() public {
        assertEq(debtToken.name(), DEBT_TOKEN_NAME);
    }

    function testSymbol() public {
        assertEq(debtToken.symbol(), DEBT_TOKEN_SYMBOL);
    }

    function testDecimals() public {
        assertEq(debtToken.decimals(), 18);
    }

    function testAllowance() public {
        vm.startPrank(user1);
        debtToken.approve(user2, 100);
        vm.stopPrank();

        uint256 allowance1 = debtToken.allowance(user1, user2);
        uint256 allowance2 = debtToken.allowance(user1, user3);

        assertEq(allowance1, 100);
        assertEq(allowance2, 0);
    }

    function testTransfer() public {
        vm.prank(user1);
        debtToken.transfer(user2, 50);
        assertEq(debtToken.balanceOf(user1), 100);
        assertEq(debtToken.balanceOf(user2), 150);
    }

    function testTransferFrom() public {
        assertEq(debtToken.allowance(user1, user2), 0);

        vm.prank(user1);
        debtToken.approve(user2, 50);
        assertEq(debtToken.allowance(user1, user2), 50);

        vm.prank(user2);
        assertTrue(debtToken.transferFrom(user1, user3, 50));
        assertEq(debtToken.balanceOf(user3), 100);
        assertEq(debtToken.balanceOf(user1), 150 - 50);

        vm.expectRevert();
        debtToken.transferFrom(user1, user3, 50);
    }

    function testMint() public {
        vm.prank(address(satoshiXApp));
        debtToken.mint(user1, 50);
        assertEq(debtToken.balanceOf(user1), 200);
    }


    function testFailMintToZero() public {
        vm.prank(address(satoshiXApp));
        debtToken.mint(address(0), 1e18);
    }

    function testFailBurnFromZero() public {
        vm.prank(address(satoshiXApp));
        debtToken.burn(address(0), 1e18);
    }

    function testFailBurnInsufficientBalance() public {
        vm.prank(user1);
        debtToken.burn(user1, 3e18);
    }

    function testFailApproveToZeroAddress() public {
        debtToken.approve(address(0), 1e18);
    }

    function testFailTransferToZeroAddress() public {
        testMint();
        vm.prank(user1);
        debtToken.transfer(address(0), 10);
    }

    function testFailTransferInsufficientBalance() public {
        testMint();
        vm.prank(user1);
        debtToken.transfer(user2, 3e18);
    }

    function testFailTransferFromInsufficientApprove() public {
        testMint();
        vm.prank(user1);
        debtToken.approve(address(this), 10);
        debtToken.transferFrom(user1, user2, 20);
    }

    
    function testPermit() public {
        IERC20Permit debtTokenPermit = IERC20Permit(address(debtToken));
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        vm.prank(address(satoshiXApp));
        debtToken.mint(owner, 1000);

        uint256 nonce = debtTokenPermit.nonces(owner);
        uint256 deadline = block.timestamp + 1000;
        uint256 amount = 1000;

        bytes32 digest = getDigest(owner, user2, amount, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        debtTokenPermit.permit(owner, user2, amount, deadline, v, r, s);

        assertEq(debtToken.allowance(owner, user2), amount);
    }

    function testFlashloan() public {
        uint256 totalSupplyBefore = debtToken.totalSupply();
        uint256 amount = 10000e18;
        FlashloanTester flashloanTester = new FlashloanTester(debtToken);
        // mint fee to tester
        vm.prank(address(satoshiXApp));
        debtToken.mint(address(flashloanTester), 9e18);
        flashloanTester.flashBorrow(address(debtToken), amount);
        assertEq(debtToken.allowance(address(this), address(flashloanTester)), 0);
        assertEq(debtToken.balanceOf(address(rewardManager)), 9e18);
        assertEq(debtToken.totalSupply() - 9e18, totalSupplyBefore);
    }

    function test_relyAndDeny() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(this)));
        debtToken.rely(address(this));

        vm.startPrank(OWNER);
        debtToken.rely(address(this));

        assertEq(debtToken.wards(address(this)), true);

        debtToken.deny(address(this));
        assertEq(debtToken.wards(address(this)), false);

        vm.stopPrank();
    }

    function testFlashFee() public {
        assertEq(debtToken.flashFee(address(0), 1000e18), 0);
        assertEq(debtToken.flashFee(address(debtToken), 1000e18), 1000e18 * 9 / 10000);
    }
    

    function getDigest(address owner, address spender, uint256 amount, uint256 nonce, uint256 deadline)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                uint16(0x1901),
                IERC20Permit(address(debtToken)).DOMAIN_SEPARATOR(),
                keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, amount, nonce, deadline))
            )
        );
    }

}

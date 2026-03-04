// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SwapInWithOkxForkTest
 * @dev BSC mainnet fork test for SatoshiPeriphery.swapInWithOkx()
 *
 * Flow being tested:
 *   USER approves RIVER → SatoshiPeriphery
 *   SatoshiPeriphery: RIVER → OKX DEX → USDT → NYM.swapIn → DebtToken → USER
 *
 * Refresh OKX_CALLDATA when stale (deadline ~1 week):
 *   curl "http://api-airdrop.river.inc/okx/nym-swap?chainId=56&fromTokenAddress=0xdA7AD9dea9397cffdDAE2F8a052B82f1484252B3&amount=1000000000000000000&slippagePercent=1"
 *   Then replace OKX_CALLDATA, OKX_APPROVE_ADDR, OKX_ROUTER below.
 *
 * Run:
 *   cd satoshi-v2
 *   forge test --match-contract SwapInWithOkxForkTest -vvvv
 *   forge test --match-contract SwapInWithOkxForkTest --match-test testDiagnostics -vvvv
 *   forge test --match-contract SwapInWithOkxForkTest --match-test testSwapInWithOkxStepByStep -vvvv
 */

import { Test } from "forge-std/Test.sol";
import { console2 as console } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISatoshiPeriphery } from "../src/core/helpers/interfaces/ISatoshiPeriphery.sol";
import { INexusYieldManagerFacet } from "../src/core/interfaces/INexusYieldManagerFacet.sol";

contract SwapInWithOkxForkTest is Test {
    // ── BSC mainnet addresses ─────────────────────────────────────────────────
    address constant PERIPHERY        = 0x246b28f44ec8CA47e83365f67Bd382D6A4952Ac8;
    address constant X_APP            = 0x07BbC5A83B83a5C440D1CAedBF1081426d0AA4Ec;
    address constant DEBT_TOKEN       = 0xb4818BB69478730EF4e33Cc068dD94278e2766cB;
    address constant RIVER_TOKEN      = 0xdA7AD9dea9397cffdDAE2F8a052B82f1484252B3;
    address constant USDT_BSC         = 0x55d398326f99059fF775485246999027B3197955;

    // Real wallet that holds RIVER on BSC (contract owner)
    address constant USER             = 0xf369359Cd4b9dABF61Aa26F19b6aa3CD88Ba39d6;

    // ── OKX addresses from /okx/nym-swap response ─────────────────────────────
    // Last fetched: 2026-03-04
    address constant OKX_APPROVE_ADDR = 0x2c34A2Fb1d0b4f55de51E1d0bDEfaDDce6b7cDD6;
    address constant OKX_ROUTER       = 0x3156020dfF8D99af1dDC523ebDfb1ad2018554a0;

    uint256 constant FROM_AMOUNT      = 1e18; // 1 RIVER

    // ── OKX calldata — each hex"" is exactly 32 bytes (64 hex chars) ──────────
    // 4-byte selector  f2c42696
    // Deadline word:   0x69a83891 = 2026-03-11 UTC (valid ~1 week from generation)
    // minReceiveAmt:   0xeaaf379c22cd1766 ≈ 16.91 USDT (1% slippage on ~17.08 USDT)
    bytes constant OKX_CALLDATA = abi.encodePacked(
        hex"f2c42696",                                                             // selector
        hex"000000000000000000000000000000000000000000000000000000000003606a",  // w1
        hex"000000000000000000000000da7ad9dea9397cffddae2f8a052b82f1484252b3",  // w2 fromToken
        hex"00000000000000000000000055d398326f99059ff775485246999027b3197955",  // w3 toToken
        hex"0000000000000000000000000000000000000000000000000de0b6b3a7640000",  // w4 amount
        hex"000000000000000000000000000000000000000000000000eaaf379c22cd1766",  // w5 minReceive
        hex"0000000000000000000000000000000000000000000000000000000069a83891",  // w6 deadline
        hex"00000000000000000000000000000000000000000000000000000000000000e0",  // w7 offset
        hex"0000000000000000000000000000000000000000000000000000000000000001",  // w8
        hex"0000000000000000000000000000000000000000000000000000000000000020",  // w9
        hex"00000000000000000000000000000000000000000000000000000000000000a0",  // w10
        hex"00000000000000000000000000000000000000000000000000000000000000e0",  // w11
        hex"0000000000000000000000000000000000000000000000000000000000000120",  // w12
        hex"0000000000000000000000000000000000000000000000000000000000000160",  // w13
        hex"000000000000000000000000da7ad9dea9397cffddae2f8a052b82f1484252b3",  // w14
        hex"0000000000000000000000000000000000000000000000000000000000000001",  // w15
        hex"0000000000000000000000007a7ad9aa93cd0a2d0255326e5fb145cec14997ff",  // w16
        hex"0000000000000000000000000000000000000000000000000000000000000001",  // w17
        hex"0000000000000000000000007a7ad9aa93cd0a2d0255326e5fb145cec14997ff",  // w18
        hex"0000000000000000000000000000000000000000000000000000000000000001",  // w19
        hex"800000000000000000012710886928eb467ef5e69b4ebc2c8af4275b21af41bd",  // w20
        hex"0000000000000000000000000000000000000000000000000000000000000001",  // w21
        hex"0000000000000000000000000000000000000000000000000000000000000020",  // w22
        hex"00000000000000000000000000000000000000000000000000000000000000a0",  // w23
        hex"0000000000000000000000000000000000000000000000000000000000000000",  // w24
        hex"0000000000000000000000000000000000000000000000000000000000000040",  // w25
        hex"0000000000000000000000000000000000000000000000000000000000000040",  // w26
        hex"000000000000000000000000da7ad9dea9397cffddae2f8a052b82f1484252b3",  // w27
        hex"00000000000000000000000055d398326f99059ff775485246999027b3197955",  // w28
        hex"777777771111800000000000000000000000000000000000ed0e13f837d6ebad",  // w29
        hex"777777771111000000000064fa00a9ed787f3793db668bff3e6e6e7db0f92a1b"   // w30
    );

    // ── Live-refresh helper ───────────────────────────────────────────────────

    struct NymSwapQuote {
        address okxApproveAddress;
        address okxRouter;
        bytes   okxCalldata;
        address stableAsset;
        address peripheryAddress;
    }

    /// @dev Calls the local backend and parses the /okx/nym-swap response.
    ///      Requires the backend to be running at api-airdrop.river.inc.
    ///      Requires ffi = true in foundry.toml (already set).
    function _fetchNymSwapQuote(
        address fromToken,
        uint256 amount,
        uint256 slippagePercent
    ) internal returns (NymSwapQuote memory q) {
        string memory url = string.concat(
            "http://api-airdrop.river.inc/okx/nym-swap?chainId=56&fromTokenAddress=",
            vm.toString(fromToken),
            "&amount=",
            vm.toString(amount),
            "&slippagePercent=",
            vm.toString(slippagePercent)
        );

        string[] memory cmd = new string[](3);
        cmd[0] = "curl";
        cmd[1] = "-s";
        cmd[2] = url;

        bytes memory raw = vm.ffi(cmd);
        string memory json = string(raw);

        q.okxApproveAddress = vm.parseJsonAddress(json, ".okxApproveAddress");
        q.okxRouter         = vm.parseJsonAddress(json, ".okxRouter");
        q.okxCalldata       = vm.parseJsonBytes(json, ".okxCalldata");
        q.stableAsset       = vm.parseJsonAddress(json, ".stableAsset");
        q.peripheryAddress  = vm.parseJsonAddress(json, ".peripheryAddress");
    }

    ISatoshiPeriphery periphery;
    IERC20 river;
    IERC20 usdt;
    IERC20 debtToken;

    function setUp() public {
        vm.createSelectFork("bsc");

        periphery = ISatoshiPeriphery(PERIPHERY);
        river     = IERC20(RIVER_TOKEN);
        usdt      = IERC20(USDT_BSC);
        debtToken = IERC20(DEBT_TOKEN);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DIAGNOSTIC — run first to inspect on-chain state without triggering swap
    // ─────────────────────────────────────────────────────────────────────────
    function testDiagnostics() public view {
        console.log("=== BSC FORK DIAGNOSTICS ===");
        console.log("block.number   :", block.number);
        console.log("block.timestamp:", block.timestamp);

        // ── Periphery fields ─────────────────────────────────────────────────
        address deployedXApp      = periphery.xApp();
        address deployedDebtToken = address(periphery.debtToken());

        console.log("\n--- SatoshiPeriphery ---");
        console.log("periphery.xApp()      :", deployedXApp);
        console.log("periphery.debtToken() :", deployedDebtToken);
        console.log("expected xApp         :", X_APP);
        console.log("expected debtToken    :", DEBT_TOKEN);
        console.log("xApp match            :", deployedXApp == X_APP);
        console.log("debtToken match       :", deployedDebtToken == DEBT_TOKEN);

        // ── swapInWithOkx exists on deployed bytecode? ────────────────────────
        // Zero-amount call will revert inside the function (not as "unknown selector")
        bytes4 sel = ISatoshiPeriphery.swapInWithOkx.selector;
        console.log("\n--- swapInWithOkx ---");
        console.logBytes4(sel);
        (bool selExists,) = PERIPHERY.staticcall(
            abi.encodeWithSelector(sel, RIVER_TOKEN, 0, address(0), address(0), hex"", USDT_BSC, 0)
        );
        // staticcall will revert (state changes) — but if selector is missing it's a different revert
        // We just check it doesn't silently return empty (i.e., function is present)
        console.log("selector call returned (expect false/revert):", selExists);

        // ── User balances ─────────────────────────────────────────────────────
        console.log("\n--- USER balances ---");
        console.log("RIVER    :", river.balanceOf(USER));
        console.log("USDT     :", usdt.balanceOf(USER));
        console.log("debtToken:", debtToken.balanceOf(USER));

        // ── NYM state ────────────────────────────────────────────────────────
        INexusYieldManagerFacet nym = INexusYieldManagerFacet(X_APP);
        bool nymPaused     = nym.isNymPaused();
        bool usdtSupported = nym.isAssetSupported(USDT_BSC);

        console.log("\n--- NYM (xApp:", X_APP, ") ---");
        console.log("NYM paused     :", nymPaused);
        console.log("USDT supported :", usdtSupported);

        if (usdtSupported) {
            console.log("mintCap        :", nym.debtTokenMintCap(USDT_BSC));
            console.log("dailyCap       :", nym.dailyDebtTokenMintCap(USDT_BSC));
            console.log("dailyRemain    :", nym.debtTokenDailyMintCapRemain(USDT_BSC));
            console.log("totalMinted    :", nym.debtTokenMinted(USDT_BSC));
            console.log("feeIn(1e18=1%) :", nym.feeIn(USDT_BSC));
        }

        // ── OKX contract code ─────────────────────────────────────────────────
        console.log("\n--- OKX contracts ---");
        console.log("OKX_APPROVE_ADDR codeSize:", OKX_APPROVE_ADDR.code.length);
        console.log("OKX_ROUTER       codeSize:", OKX_ROUTER.code.length);

        // ── Periphery residual balances ───────────────────────────────────────
        console.log("\n--- Periphery residual balances ---");
        console.log("RIVER    :", river.balanceOf(PERIPHERY));
        console.log("USDT     :", usdt.balanceOf(PERIPHERY));
        console.log("debtToken:", debtToken.balanceOf(PERIPHERY));

        // ── Calldata length sanity ────────────────────────────────────────────
        console.log("\nOKX_CALLDATA length (bytes):", OKX_CALLDATA.length);
        // expected: 4 + 30*32 = 964
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP-BY-STEP — isolates exactly which sub-step fails
    // ─────────────────────────────────────────────────────────────────────────
    function testSwapInWithOkxStepByStep() public {
        console.log("=== STEP-BY-STEP SWAP TEST ===");
        console.log("block:", block.number, "| ts:", block.timestamp);
        console.log("calldata length:", OKX_CALLDATA.length);

        deal(address(river), USER, FROM_AMOUNT);

        // ── Step 1: USER → Periphery transfer ────────────────────────────────
        console.log("\n[Step 1] transferFrom USER -> Periphery");
        vm.prank(USER);
        river.approve(PERIPHERY, FROM_AMOUNT);

        uint256 periRiverBefore = river.balanceOf(PERIPHERY);
        vm.prank(PERIPHERY);
        river.transferFrom(USER, PERIPHERY, FROM_AMOUNT);
        uint256 periRiverAfter = river.balanceOf(PERIPHERY);
        console.log("Periphery RIVER delta:", periRiverAfter - periRiverBefore);
        require(periRiverAfter - periRiverBefore == FROM_AMOUNT, "Step 1 FAILED");
        console.log("[Step 1] PASS");

        // ── Step 2: Periphery approves OKX ───────────────────────────────────
        console.log("\n[Step 2] Periphery approves OKX proxy + router");
        vm.startPrank(PERIPHERY);
        river.approve(OKX_APPROVE_ADDR, FROM_AMOUNT);
        river.approve(OKX_ROUTER, FROM_AMOUNT);
        console.log("Allowance -> OKX_APPROVE_ADDR:", river.allowance(PERIPHERY, OKX_APPROVE_ADDR));
        console.log("Allowance -> OKX_ROUTER      :", river.allowance(PERIPHERY, OKX_ROUTER));
        vm.stopPrank();
        console.log("[Step 2] PASS");

        // ── Step 3: Call OKX router (RIVER → USDT) ───────────────────────────
        console.log("\n[Step 3] OKX router call: RIVER -> USDT");
        uint256 periUsdtBefore = usdt.balanceOf(PERIPHERY);
        uint256 periRiverPre   = river.balanceOf(PERIPHERY);

        vm.prank(PERIPHERY);
        (bool okxSuccess, bytes memory okxReturnData) = OKX_ROUTER.call(OKX_CALLDATA);

        uint256 periUsdtAfter = usdt.balanceOf(PERIPHERY);
        uint256 periRiverPost = river.balanceOf(PERIPHERY);

        console.log("OKX call success  :", okxSuccess);
        console.log("RIVER consumed    :", periRiverPre - periRiverPost);
        console.log("USDT received     :", periUsdtAfter - periUsdtBefore);

        if (!okxSuccess) {
            console.log("OKX revert bytes:");
            console.logBytes(okxReturnData);
            if (okxReturnData.length >= 4) {
                bytes4 errSel = bytes4(okxReturnData);
                console.log("error selector:");
                console.logBytes4(errSel);
                // Try to decode as Error(string)
                if (errSel == bytes4(keccak256("Error(string)"))) {
                    bytes memory stripped = new bytes(okxReturnData.length - 4);
                    for (uint256 i = 0; i < stripped.length; i++) stripped[i] = okxReturnData[i + 4];
                    (string memory reason) = abi.decode(stripped, (string));
                    console.log("revert reason:", reason);
                }
            }
            revert("Step 3 FAILED: OKX swap reverted");
        }

        uint256 usdtReceived = periUsdtAfter - periUsdtBefore;
        require(usdtReceived > 0, "Step 3 FAILED: No USDT received from OKX");
        console.log("[Step 3] PASS - USDT received:", usdtReceived);

        // ── Step 4: NYM.swapIn (USDT → debtToken) ────────────────────────────
        console.log("\n[Step 4] NYM.swapIn: USDT -> debtToken");

        INexusYieldManagerFacet nym = INexusYieldManagerFacet(X_APP);
        console.log("USDT supported in NYM :", nym.isAssetSupported(USDT_BSC));
        console.log("NYM paused            :", nym.isNymPaused());
        console.log("daily cap remain      :", nym.debtTokenDailyMintCapRemain(USDT_BSC));

        uint256 periDebtBefore = debtToken.balanceOf(PERIPHERY);

        vm.startPrank(PERIPHERY);
        usdt.approve(X_APP, usdtReceived);
        uint256 debtMinted = nym.swapIn(USDT_BSC, PERIPHERY, usdtReceived);
        vm.stopPrank();

        uint256 periDebtAfter = debtToken.balanceOf(PERIPHERY);
        console.log("debtToken return val   :", debtMinted);
        console.log("debtToken balance delta:", periDebtAfter - periDebtBefore);
        require(periDebtAfter > periDebtBefore, "Step 4 FAILED: No debtToken received from NYM");
        console.log("[Step 4] PASS - debtToken received:", debtMinted);

        // ── Step 5: Transfer debtToken to user ───────────────────────────────
        console.log("\n[Step 5] Transfer debtToken to USER");
        uint256 userDebtBefore = debtToken.balanceOf(USER);
        vm.prank(PERIPHERY);
        debtToken.transfer(USER, debtMinted);
        uint256 userDebtAfter = debtToken.balanceOf(USER);
        console.log("USER debtToken received:", userDebtAfter - userDebtBefore);
        require(userDebtAfter - userDebtBefore == debtMinted, "Step 5 FAILED");
        console.log("[Step 5] PASS");

        console.log("\n=== ALL STEPS PASSED ===");
        console.log("Total debtToken to user:", debtMinted);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // END-TO-END — calls swapInWithOkx() on the deployed contract
    // ─────────────────────────────────────────────────────────────────────────
    function testSwapInWithOkxE2E() public {
        console.log("=== E2E: swapInWithOkx() block:", block.number);

        deal(address(river), USER, FROM_AMOUNT);

        uint256 userDebtBefore  = debtToken.balanceOf(USER);
        uint256 userRiverBefore = river.balanceOf(USER);
        console.log("USER RIVER before    :", userRiverBefore);
        console.log("USER debtToken before:", userDebtBefore);

        vm.startPrank(USER);
        river.approve(PERIPHERY, FROM_AMOUNT);

        periphery.swapInWithOkx(
            RIVER_TOKEN,
            FROM_AMOUNT,
            OKX_APPROVE_ADDR,
            OKX_ROUTER,
            OKX_CALLDATA,
            USDT_BSC,
            0 // minDebtAmount = 0 to skip slippage guard while debugging
        );
        vm.stopPrank();

        uint256 userDebtAfter  = debtToken.balanceOf(USER);
        uint256 userRiverAfter = river.balanceOf(USER);

        console.log("USER RIVER after     :", userRiverAfter);
        console.log("USER debtToken after :", userDebtAfter);
        console.log("debtToken received   :", userDebtAfter - userDebtBefore);

        assertGt(userDebtAfter, userDebtBefore, "E2E: User must receive debtToken");
        assertLe(userRiverAfter, userRiverBefore, "E2E: RIVER must be consumed");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LIVE test — fetches fresh calldata from the local backend at runtime.
    // Requires: backend running on api-airdrop.river.inc AND ffi = true (already set).
    // Run alone:  forge test --match-test testSwapInWithOkxLive -vvvv
    // ─────────────────────────────────────────────────────────────────────────
    function testSwapInWithOkxLive() public {
        console.log("=== LIVE E2E TEST (fresh calldata via /okx/nym-swap) ===");

        NymSwapQuote memory q = _fetchNymSwapQuote(RIVER_TOKEN, FROM_AMOUNT, 1);

        console.log("okxApproveAddress :", q.okxApproveAddress);
        console.log("okxRouter         :", q.okxRouter);
        console.log("stableAsset       :", q.stableAsset);
        console.log("peripheryAddress  :", q.peripheryAddress);
        console.log("okxCalldata length:", q.okxCalldata.length);

        deal(address(river), USER, FROM_AMOUNT);

        uint256 userDebtBefore  = debtToken.balanceOf(USER);
        uint256 userRiverBefore = river.balanceOf(USER);
        console.log("USER RIVER before    :", userRiverBefore);
        console.log("USER debtToken before:", userDebtBefore);

        vm.startPrank(USER);
        river.approve(q.peripheryAddress, FROM_AMOUNT);

        ISatoshiPeriphery(q.peripheryAddress).swapInWithOkx(
            RIVER_TOKEN,
            FROM_AMOUNT,
            q.okxApproveAddress,
            q.okxRouter,
            q.okxCalldata,
            q.stableAsset,
            0
        );
        vm.stopPrank();

        uint256 userDebtAfter  = debtToken.balanceOf(USER);
        uint256 userRiverAfter = river.balanceOf(USER);
        console.log("USER RIVER after     :", userRiverAfter);
        console.log("USER debtToken after :", userDebtAfter);
        console.log("debtToken received   :", userDebtAfter - userDebtBefore);

        assertEq(userRiverAfter, 0, "All RIVER should be spent");
        assertGt(userDebtAfter, userDebtBefore, "User must receive debtToken");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SLIPPAGE GUARD — expects revert when minDebtAmount is unreachable
    // ─────────────────────────────────────────────────────────────────────────
    function testSwapInWithOkxSlippageRevert() public {
        deal(address(river), USER, FROM_AMOUNT);

        vm.startPrank(USER);
        river.approve(PERIPHERY, FROM_AMOUNT);

        vm.expectRevert(); // SlippageTooHigh(actual, minimum)
        periphery.swapInWithOkx(
            RIVER_TOKEN,
            FROM_AMOUNT,
            OKX_APPROVE_ADDR,
            OKX_ROUTER,
            OKX_CALLDATA,
            USDT_BSC,
            type(uint256).max
        );
        vm.stopPrank();
    }
}

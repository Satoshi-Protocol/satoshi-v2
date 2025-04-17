// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AssetConfig, INexusYieldManagerFacet } from "../src/core/interfaces/INexusYieldManagerFacet.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant SATOSHI_X_APP_ADDRESS = 0x2863E3D0f29E2EEC6adEFC0dF0d3171DaD542c02;
address constant ASSET_ADDRESS = 0x62b4B8F5a03e40b9dAAf95c7A6214969406e28c3;
uint256 constant FEE_IN = 0; // 0/10000
uint256 constant FEE_OUT = 0; // 0/10000
uint256 constant DEBT_TOKEN_MINT_CAP = 1e27; // 1e9 * 1e18 = 1e27
uint256 constant DAILY_MINT_CAP = 1_000_000e18;
uint256 constant SWAP_WAITING_PERIOD = 0; // 0 seconds
uint256 constant MAX_PRICE = 1.05e18; // 1e18
uint256 constant MIN_PRICE = 0.95e18; // 1e18
bool constant IS_USING_ORACLE = false; // satUSD V1 -> satUSD V2

contract SetNYMAssetConfigScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    INexusYieldManagerFacet internal NYMFacet;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        NYMFacet = INexusYieldManagerFacet(SATOSHI_X_APP_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        AssetConfig memory assetConfig = AssetConfig({
            feeIn: FEE_IN,
            feeOut: FEE_OUT,
            debtTokenMintCap: DEBT_TOKEN_MINT_CAP,
            dailyDebtTokenMintCap: DAILY_MINT_CAP,
            debtTokenMinted: 0, // this value will be skipped in `setAssetConfig` function
            swapWaitingPeriod: SWAP_WAITING_PERIOD,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE,
            isUsingOracle: IS_USING_ORACLE
        });

        NYMFacet.setAssetConfig(ASSET_ADDRESS, assetConfig);

        console2.log("NYM asset config set");
        console2.log("Asset address:", ASSET_ADDRESS);
        console2.log("Fee in:", FEE_IN);
        console2.log("Fee out:", FEE_OUT);
        console2.log("Debt token mint cap:", DEBT_TOKEN_MINT_CAP);
        console2.log("Daily mint cap:", DAILY_MINT_CAP);
        console2.log("Swap waiting period:", SWAP_WAITING_PERIOD);
        console2.log("Max price:", MAX_PRICE);
        console2.log("Min price:", MIN_PRICE);
        console2.log("Is using oracle:", IS_USING_ORACLE);

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";

library Config {
    struct ConfigData {
        address weth;
        address lzEndpoint;
    }

    string constant DEBT_TOKEN_NAME = "SATOSHI_STABLECOIN";
    string constant DEBT_TOKEN_SYMBOL = "satUSD";

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function getConfig() public view returns (bytes memory) {
        string memory latestRunPath = string.concat("script/configs/", vm.toString(block.chainid), ".json");

        string memory json = vm.readFile(latestRunPath);
        return vm.parseJson(json);
    }
}

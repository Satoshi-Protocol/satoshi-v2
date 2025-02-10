// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ITroveManager } from "../../interfaces/ITroveManager.sol";

struct Collateral {
    address collateral;
    address[] troveManagers;
}

interface ITroveManagerGetter {
    function satoshiXApp() external view returns (address);

    function getAllCollateralsAndTroveManagers() external view returns (Collateral[] memory);

    function getActiveTroveManagersForAccount(address account)
        external
        view
        returns (ITroveManager[] memory, uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITroveManager} from "./ITroveManager.sol";

interface IDebtToken is IERC20 {
    function burn(address _account, uint256 _amount) external;

    function burnWithGasCompensation(address _account, uint256 _amount) external returns (bool);

    function enableTroveManager(ITroveManager _troveManager) external;

    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        returns (bool);

    function mint(address _account, uint256 _amount) external;

    function mintWithGasCompensation(address _account, uint256 _amount) external returns (bool);

    function returnFromPool(address _poolAddress, address _receiver, uint256 _amount) external;

    function sendToSP(address _sender, uint256 _amount) external;

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function DEBT_GAS_COMPENSATION() external view returns (uint256);

    function FLASH_LOAN_FEE() external view returns (uint256);

    function satoshiXapp() external view returns (address);

    function flashFee(address token, uint256 amount) external view returns (uint256);

    function maxFlashLoan(address token) external view returns (uint256);


    function troveManager(ITroveManager) external view returns (bool);

    // function initialize(
    //     ISatoshiCore _satoshiCore,
    //     string memory _name,
    //     string memory _symbol,
    //     IStabilityPool _stabilityPool,
    //     IBorrowerOperations _borrowerOperations,
    //     IFactory _factory,
    //     IGasPool _gasPool,
    //     uint256 _gasCompensation
    // ) external;

    function wards(address) external view returns (bool);

    function rely(address) external;

    function deny(address) external;
}

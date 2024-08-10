// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {XApp} from "lib/omni/contracts/core/src/pkg/XApp.sol";
import {ConfLevel} from "lib/omni/contracts/core/src/libraries/ConfLevel.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Utils} from "../library/Utils.sol";

struct XData {
    address to;
    bytes data;
    CallbackData callbackData;
}

struct CallbackData {
    uint64 chainId;
    address to;
    bytes data;
    uint64 gasLimit;
}

contract XAppRouter is Initializable, OwnableUpgradeable, XApp {
    address public satoshiXApp;

    modifier onlyXCall() {
        require(omni.isXCall(), "not xcall");
        _;
    }

    //TODO change to initialize
    constructor(address _portal) XApp(_portal, ConfLevel.Finalized) {
        _disableInitializers();
    }

    function initialize(address _satoshiXApp, address owner) external initializer {
        Utils.ensureNonzeroAddress(_satoshiXApp);
        Utils.ensureNonzeroAddress(owner);

        __Ownable_init_unchained(owner);

        satoshiXApp = _satoshiXApp;
    }

    function callToXApp(bytes memory data) public xrecv onlyXCall {
        XData memory xData = abi.decode(data, (XData));

        require(xData.to == satoshiXApp, "XAppRouter: Invalid to address");

        (bool success,) = xData.to.call(xData.data);

        if (!success) {
            _xCallback(xData.callbackData);
        }
    }

    function _xCallback(CallbackData memory callbackData) internal {
        xcall(callbackData.chainId, callbackData.to, callbackData.data, callbackData.gasLimit);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AppStorage } from "../AppStorage.sol";
import { Config } from "../Config.sol";

library RecoveryModeGracePeriodLib {
    event GracePeriodStart();
    event GracePeriodEnd();
    event GracePeriodDurationSet(uint128 _gracePeriod);

    function _startGracePeriod(AppStorage.Layout storage s) internal {
        if (s.lastGracePeriodStartTimestamp == Config.UNSET_TIMESTAMP) {
            s.lastGracePeriodStartTimestamp = uint128(block.timestamp);

            emit GracePeriodStart();
        }
    }

    function _endGracePeriod(AppStorage.Layout storage s) internal {
        if (s.lastGracePeriodStartTimestamp != Config.UNSET_TIMESTAMP) {
            s.lastGracePeriodStartTimestamp = Config.UNSET_TIMESTAMP;

            emit GracePeriodEnd();
        }
    }

    function _syncGracePeriod(AppStorage.Layout storage s, bool isRecoveryMode) internal {
        if (isRecoveryMode) {
            _startGracePeriod(s);
        } else {
            _endGracePeriod(s);
        }
    }
}

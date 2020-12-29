// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "../APRedemption.sol";

contract TestAPUpgrade is APRedemption {
    constructor(address farm_, address ap_) APRedemption(farm_) {
        ap = HarvestAP(ap_);
    }
}

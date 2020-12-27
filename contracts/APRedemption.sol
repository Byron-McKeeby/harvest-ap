// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./HarvestAP.sol";

interface APRedemptionI {
    function sweep() external returns (uint256);
    function redeem(uint256 toRedeem_) external returns (uint256);
    function redeemTo(uint256 toRedeem_, address recipient_) external returns (uint256);
}

/// Should be deployed by the harvest AP.
contract APRedemption is APRedemptionI {
    using SafeMath for uint256;

    // we know FARM is correctly implemented, so no need for SafeERC20
    IERC20 immutable public farm;
    HarvestAP immutable public ap;

    // Arg is the address of the FARM token to be distributed
    // - Future versions must set AP in the constructor
    constructor(address farm_) {
        farm = IERC20(farm_);
        ap = HarvestAP(msg.sender);
    }

    function farmBalance() internal view returns (uint256) {
        return farm.balanceOf(address(this));
    }

    // Can be used to preflight redemption amount
    function calcRedemption(uint256 toRedeem) public view returns (uint256) {
        return toRedeem.mul(farmBalance()).div(ap.totalSupply());
    }

    // redeem tokens and transfer farm to recipient
    function redeemTo(uint256 toRedeem_, address recipient_) public override returns (uint256) {
        // this calculation must be done before redeeming
        uint256 farmAmnt_ = calcRedemption(toRedeem_);

        // redemption balance is enforced in the HarvestAP logic.
        // No need for additional checks here
        ap.redeem(msg.sender, toRedeem_);
        farm.transfer(recipient_, farmAmnt_);
    }

    // shortcut for redeem to self
    function redeem(uint256 toRedeem_) external override returns (uint256) {
        return redeemTo(toRedeem_, msg.sender);
    }

    // Allow the AP to sweep farm from the redemption contract
    function sweep() external override returns (uint256) {
        require(msg.sender == address(ap), "APRedemption/sweep - only AP Token may call");
        farm.transfer(address(ap), farmBalance());
    }
}

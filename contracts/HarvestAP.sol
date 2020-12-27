// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./APRedemption.sol";

contract HarvestAP is ERC20, Ownable {

    address public redemption;

    // Arguments are:
    //  owner_ - who can mint
    //  farm_ - the FARM token that is distributed by the redemption
    constructor (address owner_, address farm_)
        ERC20("Harvest Action Points", "AP")
        Ownable()
    {
        transferOwnership(owner_);
        redemption = address(new APRedemption(farm_));
    }

    // In case we ever want to change redemption logic
    function setRedemption(address redemption_) external onlyOwner {
        redemption = redemption_;
    }

    // Make new AP
    function mint(address account_, uint256 amount_) external onlyOwner {
        _mint(account_, amount_);
    }

    // Redeem function simply burns tokens.
    // It is gated to the redemption contract.
    // We do this so we can skip `approve` steps during redemption
    function redeem(address account_, uint256 amount_) external {
        require(
            msg.sender == redemption,
            "HarvestAP/redeem - This function may only be called by APRedemption"
        );
        require(balanceOf(account_) >= amount_, "HarvestAP/redeem - Insufficient balance");
        _burn(account_, amount_);
    }

}

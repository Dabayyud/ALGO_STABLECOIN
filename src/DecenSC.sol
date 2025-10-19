// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volatility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.19;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

error DecenSC__NotOwner();
error DecenSC__BurnExceedsBalance();
error DecenSC__MintToZeroAddress();

/* 
 * @author Ayyub
 * @title DecenSC
 * @dev A decentralized smart contract template
 *Collateral: wETH, wBTC
 *Relative Stability: Low Volatility
 *This contract will be governed by DSC engine. This contract is an implementation of the ERC20.
 */

contract DecenSC is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("DecenSC", "DSC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (balance < _amount) {
            revert DecenSC__BurnExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecenSC__MintToZeroAddress();
        }
        _mint(_to, _amount);
        return true;
    }
}

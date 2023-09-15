// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20Burnable, ERC20} from "@openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

/**
 * @title Test Stable Coin
 * @author Muhammad Masood
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 *
 * This is the contract mean to be governed by TSCEngine. This contract is just the ERC20 implementation of our
 * 'test stable coin' system.
 */

contract TestStableCoin is ERC20Burnable, Ownable {
    error TestStableCoin__BurnAmountLessThanZero();
    error TestStableCoin__InsufficientBalance();
    error TestStableCoin__ZeroAddress();
    error TestStableCoin__InvalidMintAmount();

    constructor() ERC20("TestStableCoin", "TSC") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) revert TestStableCoin__BurnAmountLessThanZero();
        if (balance < _amount) revert TestStableCoin__InsufficientBalance();
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) revert TestStableCoin__ZeroAddress();
        if (_amount <= 0) revert TestStableCoin__InvalidMintAmount();
        _mint(_to, _amount);
        return true;
    }
}

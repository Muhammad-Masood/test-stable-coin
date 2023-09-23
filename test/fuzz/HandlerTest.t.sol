//SPDX-License-Identiifer: MIT
pragma solidity ^0.8.21;

// // Arrange the functions to avoid wasting runs

// // 1. The total supply of TSC should be less than the total value of collateral
// // 2. Getter view functions should never revert <- evergreen

import {TestStableCoin} from "../../src/TestStableCoin.sol";
import {TSCEngine} from "../../src/TSCEngine.sol";
import {ERC20Mock} from "openzeppelin/mocks/ERC20Mock.sol";
import {StdUtils} from "lib/forge-std/src/StdUtils.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract HandlerTest is StdUtils, Test {
    TestStableCoin tsc;
    TSCEngine tscEngine;
    ERC20Mock wETH;
    ERC20Mock wBTC;
    uint256 MAX_AMOUNT = type(uint96).max;
    uint256 public timesMintIsCalled;
    address [] public usersWithCollateralDeposited;
    MockV3Aggregator public ethUSDPriceFeed;


    constructor(TestStableCoin _tsc, TSCEngine _tscEngine) {
        tsc = _tsc;
        tscEngine = _tscEngine;
        wETH = ERC20Mock(tscEngine.getCollateralToken(0));
        wBTC = ERC20Mock(tscEngine.getCollateralToken(1));
        ethUSDPriceFeed = MockV3Aggregator(tscEngine.getPriceFeed(address (wETH)));
    }

    function mintTSC(uint256 _amount, uint256 _addressSeed) public {
        // break: mint amount > collateral value
        if(usersWithCollateralDeposited.length == 0) return ;
        address sender = usersWithCollateralDeposited[_addressSeed % usersWithCollateralDeposited.length];
        (uint256 totalTSCMinted, uint256 totalCollateralValue) = tscEngine.getAccountInfo(sender);
        uint256 maxAmountToMint =  (totalCollateralValue / (150e18/100));
        if(maxAmountToMint == 0) return;
        uint256 mintAmount = bound(_amount, 1, maxAmountToMint);
        vm.startPrank(sender);
        tscEngine.mintTSC(mintAmount);
        timesMintIsCalled++;
        vm.stopPrank();
    }

    function depositCollateral(uint256 _collateralSeed, uint256 _amount) external {
        uint256 amountBounded = bound(_amount, 1, MAX_AMOUNT);
        address collateral = address(_getCollateralToken(_collateralSeed));
        vm.startPrank(msg.sender);
        ERC20Mock(collateral).mint(msg.sender, amountBounded);
        ERC20Mock(collateral).approve(address(tscEngine),amountBounded);
        tscEngine.depositCollateral(collateral,amountBounded);
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 _collateralSeed, uint256 _amountCollateral) public {
        address collateral = address(_getCollateralToken(_collateralSeed));
        uint256 maxRedeemAmount = ERC20Mock(collateral).balanceOf(msg.sender);
        uint256 amountBounded = bound(_amountCollateral, 0, maxRedeemAmount);
        // What if we have a bug, where a user can redeem more than it have? 
        // uint256 amountBounded = bound(_amountCollateral, 0, MAX_AMOUNT);
        if(amountBounded == 0) return;
        vm.prank(msg.sender);
        tscEngine.redeemCollateral(collateral, amountBounded);

    }

    function updateCollateralPrice(uint96 _price) public {
        int256 newPriceInt = int256(uint256(_price));
        ethUSDPriceFeed.updateAnswer(newPriceInt);
    }

    function _getCollateralToken(uint256 _seed) internal returns (ERC20Mock) {
        // even case: wETH
        if(_seed % 2 == 0){ 
            return wETH;
        } else {
            return wBTC;
        }
    }


}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {TestStableCoin} from "../src/TestStableCoin.sol";
import {TSCEngine} from "../src/TSCEngine.sol";
import {TSCScript} from "../script/DeployTSC.s.sol";
import {console} from "lib/forge-std/src/console.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "openzeppelin/mocks/ERC20Mock.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin/interfaces/IERC20.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

contract TestStableCoinTest is Test {
    TestStableCoin private tsc;
    TSCEngine private tscEngine;
    HelperConfig private config;
    ERC20Mock private erc20Mock;
    // TSCScript private tscScript;

    address wETH;
    address wBTC;
    address wETHPriceFeed;
    address wBTCPriceFeed;
    address [] tokenAddresses;
    address [] priceFeedAddresses;

    address user = makeAddr("user");
    uint256 depositCollateralAmount = 10e18;
    uint256 mintTSCAmount = 13000e18;
    uint256 private constant STARTING_WETH_BALANCE = 100e18;

    event RedeemCollateral(address indexed user, address indexed collateralAddress, uint256 indexed amount);

    function setUp() external {
        TSCScript tscScript = new TSCScript();
        (tsc, tscEngine, config) = tscScript.run();
        (wETH,wBTC,wETHPriceFeed,wETHPriceFeed,) = config.getActiveNetworkConfig();
        vm.prank(address(tscScript));
        ERC20Mock(wETH).transfer(user, STARTING_WETH_BALANCE);
        console.log("script wETH balance", ERC20Mock(wETH).balanceOf(address(tscScript)));
        console.log("user wETH balance: ", ERC20Mock(wETH).balanceOf(user));
    }

    // Constructor 

    function testTokenAddressAndPriceFeedAddressLengthMatch() public {
        tokenAddresses.push(wETH);
        tokenAddresses.push(wBTC);
        priceFeedAddresses.push(wETHPriceFeed);
        vm.expectRevert(TSCEngine.DSCEngine__TokenAdressAndPriceFeedAddressLengthMismatched.selector);
        new TSCEngine(tsc, tokenAddresses,priceFeedAddresses);
    }

    function testCorrectUSDPrice() public {
        uint256 ethAmount = 15e18;
        uint256 getETHUSDPrice = tscEngine.getUSDValue(wETH, ethAmount);
        uint256 expectedUSDPrice = 30000e18;
        console.log(getETHUSDPrice);
        assertEq(getETHUSDPrice, expectedUSDPrice);
    }

    function testGetCollateralAmountFromUSD() public {
        // 100$ TSC -> ETH?
        // 2000 USD/ETH -> 100/2000 = 0.05 ETH
        uint256 tokenAmount = 100 ether;
        uint256 expectedETHAmount = 0.05 ether;
        uint256 amountETH = tscEngine.getCollateralAmountFromUSD(wETH,tokenAmount);
        assertEq(amountETH, expectedETHAmount);
    }

    // deposit collateral

    modifier depositCollateral(address _collateral, uint256 _collateralAmount) {
        vm.startPrank(user);
        ERC20Mock(_collateral).approve(address(tscEngine), _collateralAmount);
        tscEngine.depositCollateral(_collateral, _collateralAmount);
        vm.stopPrank();
        _;
    }

    modifier mintTSC(uint256 _mintAmount) {
        vm.prank(user);
        tscEngine.mintTSC(_mintAmount);
        _;
    }

    function testRevertIfCollateralZero() public {
        vm.prank(user);
        vm.expectRevert(TSCEngine.DSCEngine__ZeroAmount.selector);
        tscEngine.depositCollateral(wETH, 0);
    }

    function testRevertIfCollateralNotAllowed() public {
        ERC20Mock newCollateral = new ERC20Mock("NewToken","new",user,depositCollateralAmount);
        vm.prank(user);
        vm.expectRevert(TSCEngine.DSCEngine__TokenNotAllowed.selector);
        tscEngine.depositCollateral(address(newCollateral), depositCollateralAmount);
    }

    function testDepositCollateralIfCollateralNotZeroAndAllowed() public {
        vm.startPrank(user);
        uint256 totalTSCMinted_before = 0;
        uint256 collateralValueInUSD_before = 0;
        address collateral = wETH;
        uint256 collateralAmountToDeposit = depositCollateralAmount;
        // uint256 beforeCollateralAmount = tscEngine.getDepositedCollateral(wETH);
        ERC20Mock(wETH).approve(address(tscEngine), collateralAmountToDeposit);
        tscEngine.depositCollateral(collateral, collateralAmountToDeposit);
        
        uint256 expectedTSCMinted = totalTSCMinted_before; //only depositing
        uint256 expectedCollateralValueInUSD = collateralValueInUSD_before + tscEngine.getUSDValue(collateral, collateralAmountToDeposit);

        (uint256 totalTSCMinted, uint256 collateralValueInUSD) = tscEngine.getAccountInfo(user);

        assertEq(totalTSCMinted,expectedTSCMinted);
        assertEq(collateralValueInUSD, expectedCollateralValueInUSD);

        vm.stopPrank();
    }

    // mint tsc

    function testRevertIfHealthFactorBroken() public depositCollateral(wETH, depositCollateralAmount) {
        // collateral: 20,000$ -> 20000/1.5 -> mint: 13,333$ TSC 
        uint256 mintAmount = 14000 ether;
        vm.expectRevert(TSCEngine.DSCEngine__HealthFactorBroken.selector);
        tscEngine.mintTSC(mintAmount);
    }


    function testMintTSC() public depositCollateral(wETH,depositCollateralAmount) {
        // deposit: 10 wETH -> 20,000$
        console.log("tsc from test ",address(tsc));
        uint256 balanceTSC_before = ERC20Mock(address (tsc)).balanceOf(user);
        vm.startPrank(user);
        (uint256 totalTSCMinted_before,uint256 value_before) = tscEngine.getAccountInfo(user);
        console.log("total tsc minted before: ", totalTSCMinted_before, value_before);
        tscEngine.mintTSC(mintTSCAmount);
        (uint256 totalTSCMinted_current, uint256 value_after) = tscEngine.getAccountInfo(user);
        console.log("total tsc minted after: ", totalTSCMinted_current, value_after);
        vm.stopPrank();
        uint256 expctedMintedTSC = totalTSCMinted_before + mintTSCAmount;
        uint256 expectedTSCBalance = balanceTSC_before + mintTSCAmount;
        assertEq(totalTSCMinted_current,expctedMintedTSC);
        assertEq(tsc.balanceOf(user), expectedTSCBalance);
    }

    // redeem tsc

    function testRedeemCollateralFailedIfHealthFactorBreaks() public depositCollateral(wETH,depositCollateralAmount) mintTSC(mintTSCAmount) {
        // deposit: 10 wETH/20,000$ -> mint: 13,000$ -> redeem: 0.5 wETH/1000$
        uint256 redeemCollateralAmount = 0.5 ether;
        vm.startPrank(user);
        vm.expectRevert(TSCEngine.DSCEngine__HealthFactorBroken.selector);
        tscEngine.redeemCollateral(wETH, redeemCollateralAmount);
        vm.stopPrank();
    }
    
    function testRedeemCollateral() public depositCollateral(wETH,depositCollateralAmount) mintTSC(mintTSCAmount) {
        // 13333 - 13000 = 333 -> 300$/0.15 wETH
        uint256 redeemCollateralAmount = 0.15 ether;
        vm.startPrank(user);
        uint256 collateralAmount_before = tscEngine.getDepositedCollateral(wETH);
        uint256 userBalance_before = ERC20Mock(wETH).balanceOf(user);
        vm.expectEmit(true,true,true,false,address(tscEngine));
        emit RedeemCollateral(user,wETH,redeemCollateralAmount);
        tscEngine.redeemCollateral(wETH, redeemCollateralAmount);
        uint256 expectedCollateralAmount = collateralAmount_before - redeemCollateralAmount;
        assertEq(tscEngine.getDepositedCollateral(wETH), expectedCollateralAmount);
        assertEq(ERC20Mock(wETH).balanceOf(user) , userBalance_before + redeemCollateralAmount);
        vm.stopPrank();
    }

    // burn tsc

    function testBurnTSC() public depositCollateral(wETH,depositCollateralAmount) mintTSC(mintTSCAmount) {
        uint256 burnAmount = 1000 ether;
        uint256 balanceTSC_before = tsc.balanceOf(user);
        (uint256 mintedTSC_before,) = tscEngine.getAccountInfo(user);
        vm.startPrank(user);
        tsc.approve(address(tscEngine),burnAmount);
        tscEngine.burnTSC(burnAmount);
        vm.stopPrank();
        uint256 expectedMintedTSC = mintedTSC_before - burnAmount;
        (uint256 mintedTSC_after,) = tscEngine.getAccountInfo(user);
        uint256 expectedTSCBalance = balanceTSC_before - burnAmount;
        assertEq(mintedTSC_after, expectedMintedTSC);
        assertEq(tsc.balanceOf(user),expectedTSCBalance);
    }

    // liquidation

    int256 DROPPED_COLLATERAL_VALUE = 1000e8;

    function testLiquidate() public {
        // manipulate the collateral value
        console.log("Prev wETH price", tscEngine.getUSDValue(wETH, 1 ether));
        MockV3Aggregator(wETHPriceFeed).updateAnswer(DROPPED_COLLATERAL_VALUE);
        console.log("Current wETH price", tscEngine.getUSDValue(wETH, 1 ether));
    }


}
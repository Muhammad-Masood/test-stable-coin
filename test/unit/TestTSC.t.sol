// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {TestStableCoin} from "../../src/TestStableCoin.sol";
import {TSCEngine} from "../../src/TSCEngine.sol";
import {TSCScript} from "../../script/DeployTSC.s.sol";
import {console} from "lib/forge-std/src/console.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "openzeppelin/mocks/ERC20Mock.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin/interfaces/IERC20.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

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
    address[] tokenAddresses;
    address[] priceFeedAddresses;

    address user = makeAddr("user");
    address liquidator = makeAddr("liquidator");
    uint256 depositCollateralAmount = 10e18;
    uint256 mintTSCAmount = 13000e18;
    uint256 constant STARTING_WETH_BALANCE = 100e18;
    int256 constant DROPPED_COLLATERAL_VALUE = 1000e8;

    event RedeemCollateral(address indexed user, address indexed collateralAddress, uint256 indexed amount);
    event CollateralDeposit(address indexed user, address indexed collateralAddress, uint256 indexed amount);

    function setUp() external {
        TSCScript tscScript = new TSCScript();
        (tsc, tscEngine, config) = tscScript.run();
        (wETH, wBTC, wETHPriceFeed, wETHPriceFeed,) = config.getActiveNetworkConfig();
        vm.startPrank(address(tscScript));
        ERC20Mock(wETH).transfer(user, STARTING_WETH_BALANCE);
        ERC20Mock(wETH).transfer(liquidator, STARTING_WETH_BALANCE);
        vm.stopPrank();
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
        uint256 amountETH = tscEngine.getCollateralAmountFromUSD(wETH, tokenAmount);
        assertEq(amountETH, expectedETHAmount);
    }

    // modifiers

    modifier depositCollateral(address _depositor, address _collateral, uint256 _collateralAmount) {
        vm.startPrank(_depositor);
        ERC20Mock(_collateral).approve(address(tscEngine), _collateralAmount);
        tscEngine.depositCollateral(_collateral, _collateralAmount);
        vm.stopPrank();
        _;
    }

    modifier depositAndMint(address _user, address _collateral, uint256 _depositAmount, uint256 mintAmount) {
        vm.startPrank(_user);
        ERC20Mock(_collateral).approve(address(tscEngine), _depositAmount);
        tscEngine.depositCollateralAndMintTSC(_collateral, _depositAmount, mintAmount);
        vm.stopPrank();
        _;
    }

    modifier mintTSC(address _minter, uint256 _mintAmount) {
        vm.prank(_minter);
        tscEngine.mintTSC(_mintAmount);
        _;
    }

    // deposit collateral

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
        uint256 depositedCollateral_before = tscEngine.getDepositedCollateral(user);
        address collateral = wETH;
        uint256 collateralAmountToDeposit = depositCollateralAmount;
        // uint256 beforeCollateralAmount = tscEngine.getDepositedCollateral(wETH);
        ERC20Mock(wETH).approve(address(tscEngine), collateralAmountToDeposit);
        vm.expectEmit(true, true, true, false, address(tscEngine));
        emit CollateralDeposit(user, collateral, collateralAmountToDeposit);
        tscEngine.depositCollateral(collateral, collateralAmountToDeposit);

        uint256 expectedTSCMinted = totalTSCMinted_before; //only depositing
        uint256 expectedCollateralValueInUSD =
            collateralValueInUSD_before + tscEngine.getUSDValue(collateral, collateralAmountToDeposit);

        (uint256 totalTSCMinted, uint256 collateralValueInUSD) = tscEngine.getAccountInfo(user);

        assertEq(totalTSCMinted, expectedTSCMinted);
        assertEq(collateralValueInUSD, expectedCollateralValueInUSD);
        assertEq(tscEngine.getDepositedCollateral(collateral), depositedCollateral_before + collateralAmountToDeposit);
        vm.stopPrank();
    }

    
    // Health Factor

    function testHealthFactor() public depositCollateral(user, wETH, depositCollateralAmount) {
        // 20,000$ -> 13,333$ collateral -> 0 minted TSC
        // 13333/0 = ? 
        tscEngine.getHealthFactor(user);
    }

    // mint tsc

    function testRevertIfHealthFactorBroken() public depositCollateral(user, wETH, depositCollateralAmount) {
        // collateral: 20,000$ -> 20000/1.5 -> mint: 13,333$ TSC
        uint256 mintAmount = 14000 ether;
        vm.startPrank(user);
        vm.expectRevert(TSCEngine.DSCEngine__HealthFactorBroken.selector);
        tscEngine.mintTSC(mintAmount);
        vm.stopPrank();
    }

    function testMintTSC() public depositCollateral(user, wETH, depositCollateralAmount) {
        // deposit: 10 wETH -> 20,000$
        uint256 balanceTSC_before = ERC20Mock(address(tsc)).balanceOf(user);
        vm.startPrank(user);
        (uint256 totalTSCMinted_before,) = tscEngine.getAccountInfo(user);
        tscEngine.mintTSC(mintTSCAmount);
        (uint256 totalTSCMinted_current,) = tscEngine.getAccountInfo(user);
        vm.stopPrank();
        uint256 expctedMintedTSC = totalTSCMinted_before + mintTSCAmount;
        uint256 expectedTSCBalance = balanceTSC_before + mintTSCAmount;
        assertEq(totalTSCMinted_current, expctedMintedTSC);
        assertEq(tsc.balanceOf(user), expectedTSCBalance);
    }

    // deposit and mint

    function testDepositCollateralAndMintTSC() public {
        uint256 collateralValueInUSD_before = 0;
        uint256 balanceTSC_before = ERC20Mock(address(tsc)).balanceOf(user);
        (uint256 totalTSCMinted_before,) = tscEngine.getAccountInfo(user);
        vm.startPrank(user);
        ERC20Mock(wETH).approve(address(tscEngine), depositCollateralAmount);
        tscEngine.depositCollateralAndMintTSC(wETH, depositCollateralAmount, mintTSCAmount);
        vm.stopPrank();
        (uint256 totalTSCMinted_current, uint256 collateralValueInUSD) = tscEngine.getAccountInfo(user);
        uint256 expctedMintedTSC = totalTSCMinted_before + mintTSCAmount;
        uint256 expectedTSCBalance = balanceTSC_before + mintTSCAmount;
        uint256 expectedCollateralValueInUSD =
            collateralValueInUSD_before + tscEngine.getUSDValue(wETH, depositCollateralAmount);
        assertEq(collateralValueInUSD, expectedCollateralValueInUSD);
        assertEq(totalTSCMinted_current, expctedMintedTSC);
        assertEq(tsc.balanceOf(user), expectedTSCBalance);
        
    }

    // redeem tsc

    function testRedeemCollateralFailedIfHealthFactorBreaks()
        public
        depositCollateral(user, wETH, depositCollateralAmount)
        mintTSC(user, mintTSCAmount)
    {
        // deposit: 10 wETH/20,000$ -> mint: 13,000$ -> redeem: 0.5 wETH/1000$
        uint256 redeemCollateralAmount = 0.5 ether;
        vm.startPrank(user);
        vm.expectRevert(TSCEngine.DSCEngine__HealthFactorBroken.selector);
        tscEngine.redeemCollateral(wETH, redeemCollateralAmount);
        vm.stopPrank();
    }

    function testRedeemCollateral()
        public
        depositCollateral(user, wETH, depositCollateralAmount)
        mintTSC(user, mintTSCAmount)
    {
        // 13333 - 13000 = 333 -> 300$/0.15 wETH
        uint256 redeemCollateralAmount = 0.15 ether;
        vm.startPrank(user);
        uint256 collateralAmount_before = tscEngine.getDepositedCollateral(wETH);
        uint256 userBalance_before = ERC20Mock(wETH).balanceOf(user);
        vm.expectEmit(true, true, true, false, address(tscEngine));
        emit RedeemCollateral(user, wETH, redeemCollateralAmount);
        tscEngine.redeemCollateral(wETH, redeemCollateralAmount);
        uint256 expectedCollateralAmount = collateralAmount_before - redeemCollateralAmount;
        assertEq(tscEngine.getDepositedCollateral(wETH), expectedCollateralAmount);
        assertEq(ERC20Mock(wETH).balanceOf(user), userBalance_before + redeemCollateralAmount);
        vm.stopPrank();
    }

    // burn tsc

    function testBurnTSC() public depositCollateral(user, wETH, depositCollateralAmount) mintTSC(user, mintTSCAmount) {
        uint256 burnAmount = 1000 ether;
        uint256 balanceTSC_before = tsc.balanceOf(user);
        (uint256 mintedTSC_before,) = tscEngine.getAccountInfo(user);
        vm.startPrank(user);
        tsc.approve(address(tscEngine), burnAmount);
        tscEngine.burnTSC(burnAmount);
        vm.stopPrank();
        uint256 expectedMintedTSC = mintedTSC_before - burnAmount;
        (uint256 mintedTSC_after,) = tscEngine.getAccountInfo(user);
        uint256 expectedTSCBalance = balanceTSC_before - burnAmount;
        assertEq(mintedTSC_after, expectedMintedTSC);
        assertEq(tsc.balanceOf(user), expectedTSCBalance);
    }

    // liquidation

    function testLiquidateFailIfHealthFactorOK()
        public
        depositAndMint(user, wETH, depositCollateralAmount, mintTSCAmount)
        depositAndMint(liquidator, wETH, depositCollateralAmount * 2, mintTSCAmount)
    {
        int256 droppedValue = 500e18;
        MockV3Aggregator(wETHPriceFeed).updateAnswer(droppedValue);
        // ratio: 1/1 -> NOT UNDERCOLLATERALIZED!
        vm.startPrank(liquidator);
        vm.expectRevert(TSCEngine.DSCEngine__HealthFactorOK.selector);
        tscEngine.liquidate(wETH, user, 0.5 ether);
        vm.stopPrank();
    }

    // revert if liquidator's health factor is breaking

    function testLiquidateFailIfHealthFactorBreaks()
        public
        depositAndMint(user, wETH, depositCollateralAmount, mintTSCAmount)
        depositAndMint(liquidator, wETH, depositCollateralAmount, mintTSCAmount)
    {
        MockV3Aggregator(wETHPriceFeed).updateAnswer(DROPPED_COLLATERAL_VALUE);
        uint256 debtToCover = 3000 ether;
        vm.startPrank(liquidator);
        tsc.approve(address(tscEngine), debtToCover);
        vm.expectRevert(TSCEngine.DSCEngine__HealthFactorBroken.selector);
        tscEngine.liquidate(wETH, user, debtToCover);
        vm.stopPrank();
    }

    function testLiquidate()
        public
        depositAndMint(user, wETH, depositCollateralAmount, mintTSCAmount)
        depositAndMint(liquidator, wETH, depositCollateralAmount * 2, mintTSCAmount)
    {
        // deposit: 20,000$/10wETH -> mint: 13000$/TSC -> PRICE DROPPED ->
        // 15,000$/7.5 wETH -> minted TSC should be: 10,000$/TSC ->
        // health factor: 0.769 -> debt: 3000$ TSC -> UNDER COLLATERALIZED!!!
        // manipulate the collateral value
        MockV3Aggregator(wETHPriceFeed).updateAnswer(DROPPED_COLLATERAL_VALUE);
        uint256 debtToCover = 3000 ether;
        // receive: 3000$/3 ETH + 10% bonus = 3300$/3.3 ETH
        uint256 receiveCollateralAmount = 3.3 ether;
        uint256 supplyTSC_before = tsc.totalSupply();
        vm.prank(user);
        uint256 depositedCollateral_user_before = tscEngine.getDepositedCollateral(wETH);
        uint256 collateralBalance_liquidator_before = ERC20Mock(wETH).balanceOf(liquidator);
        vm.startPrank(liquidator);
        tsc.approve(address(tscEngine),debtToCover);
        tscEngine.liquidate(wETH, user, debtToCover);
        vm.stopPrank();
        uint256 expectedCollateralBalance_liquidator = collateralBalance_liquidator_before + receiveCollateralAmount;
        vm.prank(user);
        assertEq(tscEngine.getDepositedCollateral(wETH), depositedCollateral_user_before - receiveCollateralAmount);
        assertEq(ERC20Mock(wETH).balanceOf(liquidator), expectedCollateralBalance_liquidator);
        assertEq(tsc.totalSupply(), supplyTSC_before - debtToCover);
    }
}

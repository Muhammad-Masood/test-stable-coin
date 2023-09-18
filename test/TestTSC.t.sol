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

contract TestStableCoinTest is Test {
    TestStableCoin private tsc;
    TSCEngine private tscEngine;
    HelperConfig private config;
    ERC20Mock private erc20Mock;
    // TSCScript private tscScript;

    error DSCEngine__ZeroAmount();
    error DSCEngine__TokenNotAllowed();

    address wETH;
    address user = makeAddr("user");
    uint256 depositCollateralAmount = 1e18;
    uint256 private constant STARTING_WETH_BALANCE = 100e18;

    function setUp() external {
        TSCScript tscScript = new TSCScript();
        (tsc, tscEngine, config) = tscScript.run();
        (wETH,,,,) = config.getActiveNetworkConfig();
        vm.prank(address(tscScript));
        ERC20Mock(wETH).transfer(user, STARTING_WETH_BALANCE);
        console.log("wETH balance", ERC20Mock(wETH).balanceOf(address(tscScript)));
        console.log("user balance: ",ERC20Mock(wETH).balanceOf(user));
        console.log("test contract: ",address(this));
    }

    function testCorrectUSDPrice() public {
        uint256 ethAmount = 15e18;
        uint256 getETHUSDPrice = tscEngine.getUSDValue(wETH, ethAmount);
        uint256 expectedUSDPrice = 30000e18;
        console.log(getETHUSDPrice);
        assertEq(getETHUSDPrice, expectedUSDPrice);
    }

    // deposit collateral

    function testRevertIfCollateralZero() public {
        vm.prank(user);
        vm.expectRevert(DSCEngine__ZeroAmount.selector);
        tscEngine.depositCollateral(wETH, 0);
    }

    function testRevertIfCollateralNotAllowed() public {
        address newCollateral = 0x958b482c4E9479a600bFFfDDfe94D974951Ca3c7;
        vm.prank(user);
        vm.expectRevert(DSCEngine__TokenNotAllowed.selector);
        tscEngine.depositCollateral(newCollateral, depositCollateralAmount);
    }

    function testDepositCollateralIfCollateralNotZeroAndAllowed() public {
        // user should have the required collateral amount
        vm.startPrank(user);
        uint256 beforeCollateralAmount = tscEngine.getDepositedCollateral(wETH);
        ERC20Mock(wETH).approve(address(tscEngine), depositCollateralAmount);
        tscEngine.depositCollateral(wETH, depositCollateralAmount);
        uint256 expectedCollateralAmount = beforeCollateralAmount + depositCollateralAmount;
        assertEq(tscEngine.getDepositedCollateral(wETH),expectedCollateralAmount);
        vm.stopPrank();
    }

    // mint tsc

    function testMintTSC() public {
        // console.log()
        uint256 mintAmount = 10e18;
        vm.startPrank(user);
        uint256 prevTSCMinted = tscEngine.getTSCMinted();
        tscEngine.mintTSC(mintAmount);
        console.log(tscEngine.getTSCMinted());
        // uint256 expectedTSCMinted = prevTSCMinted + mintAmount;
        // assertEq(tscEngine.getTSCMinted(), expectedTSCMinted);
        vm.stopPrank();
    }
}

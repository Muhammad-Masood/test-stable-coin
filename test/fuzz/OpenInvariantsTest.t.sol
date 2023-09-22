// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.21;

// import {TestStableCoin} from "../../src/TestStableCoin.sol";
// import {TSCEngine} from "../../src/TSCEngine.sol";
// import {TSCScript} from "../../script/DeployTSC.s.sol";
// import {console} from "lib/forge-std/src/console.sol";
// import {Test} from "lib/forge-std/src/Test.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {ERC20Mock} from "openzeppelin/mocks/ERC20Mock.sol";
// import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
// import {IERC20} from "openzeppelin/interfaces/IERC20.sol";
// import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
// import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";

// contract OpenInvariantsTest is StdInvariant, Test {
//     TestStableCoin private tsc;
//     TSCEngine private tscEngine;
//     HelperConfig private config;
//     ERC20Mock private erc20Mock;
//     address wETH;
//     address wBTC;

//     function setUp() external {
//         TSCScript tscScript = new TSCScript();
//         (tsc, tscEngine, config) = tscScript.run();
//         (wETH, wBTC,,,) = config.getActiveNetworkConfig();
//         targetContract(address(tscEngine));
//         // console.log("total supply: ", tsc.totalSupply());
//     }

//     // collateral must be greater than the total TSC minted
//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         uint256 totalSupply = tsc.totalSupply();
//         uint256 wETHDeposited = IERC20(wETH).balanceOf(address(tscEngine));
//         uint256 wBTCDeposited = IERC20(wBTC).balanceOf(address(tscEngine));
//         uint256 wETHDepositedValue = tscEngine.getUSDValue(wETH, wETHDeposited);
//         uint256 wBTCDepositedValue = tscEngine.getUSDValue(wBTC, wBTCDeposited);
//         uint256 totalCollateralValue = wETHDepositedValue + wBTCDepositedValue;
//         assert(totalCollateralValue >= totalSupply);
//     }
// }

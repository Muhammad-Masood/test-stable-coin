// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {TestStableCoin} from "../src/TestStableCoin.sol";
import {TSCEngine} from "../src/TSCEngine.sol";
import {Script} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

contract TSCScript is Script {
    uint256 private constant NUMBER_OF_TOKENS = 2;
    address[] private tokensAddresses;
    address[] private priceFeedsAddresses;

    function run() external returns (TestStableCoin, TSCEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (address wETH, address wBTC, address wETHPriceFeed, address wBTCPriceFeed, uint256 deployerKey) =
            config.getActiveNetworkConfig();
            tokensAddresses = [wETH, wBTC];
            priceFeedsAddresses = [wETHPriceFeed, wBTCPriceFeed];
        vm.startBroadcast(deployerKey);
        TestStableCoin testStableCoin = new TestStableCoin();
        TSCEngine tscEngine = new TSCEngine(testStableCoin, tokensAddresses, priceFeedsAddresses);
        testStableCoin.transferOwnership(address(tscEngine));
        vm.stopBroadcast();

        // vm.startBroadcast(address(tscEngine));
        // TestStableCoin testStableCoin = new TestStableCoin();
        // vm.stopBroadcast();

        console.log("TSC owner: ", testStableCoin.owner());
        uint256 engineTSCBalance = IERC20(address(testStableCoin)).balanceOf(address(tscEngine));
        console.log("TSC Engine balance: ", engineTSCBalance);
        return (testStableCoin, tscEngine, config);
    }
}

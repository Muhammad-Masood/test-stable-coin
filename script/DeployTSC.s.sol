// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {TestStableCoin} from "../src/TestStableCoin.sol";
import {TSCEngine} from "../src/TSCEngine.sol";
import {Script} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";

contract TSCScript is Script {

    uint256 private constant NUMBER_OF_TOKENS = 2;
    address [] private tokensAddresses;
    address [] private priceFeedsAddresses;

    function run() external returns (TestStableCoin, TSCEngine) {
        vm.startBroadcast();
        TestStableCoin testStableCoin = new TestStableCoin();
        TSCEngine tscEngine = new TSCEngine(NUMBER_OF_TOKENS, ???? );
        vm.stopBroadcast();
        return (testStableCoin, tscEngine);
    }
}

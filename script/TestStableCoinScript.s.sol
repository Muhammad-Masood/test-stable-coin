// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {TestStableCoin} from "../src/TestStableCoin.sol";
import {Script} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";

contract TestStableCoinScript is Script {
    function run() external returns (TestStableCoin) {
        TestStableCoin testStableCoin = new TestStableCoin();
        return testStableCoin;
    }
}

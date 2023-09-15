// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {TestStableCoin} from "../src/TestStableCoin.sol";
import {TestStableCoinScript} from "../script/TestStableCoinScript.s.sol";
import {console} from "lib/forge-std/src/console.sol";
import {Test} from "lib/forge-std/src/Test.sol";

contract TestStableCoinTest is Test {
    TestStableCoin private testStableCoin;

    function setUp() external returns (bool) {
        TestStableCoinScript testStableCoinScript = new TestStableCoinScript();
        testStableCoin = testStableCoinScript.run();
        return true;
    }
}

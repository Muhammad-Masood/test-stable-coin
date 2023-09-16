// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {TestStableCoin} from "../src/TestStableCoin.sol";
import {TSCEngine} from "../src/TSCEngine.sol";
import {TSCScript} from "../script/DeployTSC.s.sol";
import {console} from "lib/forge-std/src/console.sol";
import {Test} from "lib/forge-std/src/Test.sol";

contract TestStableCoinTest is Test {
    TestStableCoin private testStableCoin;
    TSCEngine private tescEngine;

    function setUp() external returns (bool) {
        TSCScript tscScript = new TSCScript();
        testStableCoin = tscScript.run();
        return true;
    }
}

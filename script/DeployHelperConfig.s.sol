// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "../src/HelperConfig.sol";

contract HelperConfigScript is Script {

    function run()  returns (HelperConfig) {
        vm.startBroadcast();
        HelperConfig helperConfig = new HelperConfig();
        vm.stopBroadcast();
        return helperConfig;
    }
}
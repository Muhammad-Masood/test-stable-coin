// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20Mock} from "@openzeppelin/mocks/ERC20Mock.sol";

contract HelperConfig {
    struct NetworkConfig {
        address wETH;
        address wBTC;
        address wETHPriceFeed;
        address wBTCPriceFeed;
        uint256 deployerKey;
    }

    NetworkConfig private activeNetworkConfig;

    constructor() {
        setHelperConfig();
    }

    function setHelperConfig() internal returns (address) {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getEthereumNetworkConfig();
        } else if (block.chainid == 31337) {
            activeNetworkConfig = getOrCreateAnvilNetworkConfig();
        }
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function getSepoliaNetworkConfig() internal view {
        return ({
            wETH:
            wBTC:
            wETHPriceFeed:0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wBTCPriceFeed:0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            deployerKey: env.uint("PRIVATE_KEY");
        })
    }

    function getEthereumNetworkConfig() internal view {
        return ({

        })
    }

    function getOrCreateAnvilNetworkConfig() internal view {
        if(){

        }
        return ({
            
        })
    }
}

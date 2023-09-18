// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20Mock} from "@openzeppelin/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {Script} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wETH;
        address wBTC;
        address wETHPriceFeed;
        address wBTCPriceFeed;
        uint256 deployerKey;
    }

    NetworkConfig private activeNetworkConfig;
    uint8 private constant DECIMALS = 8;
    int256 private constant ETH_PRICE_USD = 2000e8;
    int256 private constant BTC_PRICE_USD = 1000e8;
    uint256 private constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        setHelperConfig();
    }

    function setHelperConfig() internal {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getEthereumNetworkConfig();
        } else if (block.chainid == 31337) {
            activeNetworkConfig = getOrCreateAnvilNetworkConfig();
        }
    }

    function getActiveNetworkConfig() public view returns (address, address, address, address, uint256) {
        return (
            activeNetworkConfig.wETH,
            activeNetworkConfig.wBTC,
            activeNetworkConfig.wETHPriceFeed,
            activeNetworkConfig.wBTCPriceFeed,
            activeNetworkConfig.deployerKey
        );
    }

    function getSepoliaNetworkConfig() internal view returns (NetworkConfig memory) {
        return NetworkConfig({
            wETH: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wBTC: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            wETHPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wBTCPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getEthereumNetworkConfig() internal view returns (NetworkConfig memory) {
        return NetworkConfig({
            wETH: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            wBTC: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            wETHPriceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            wBTCPriceFeed: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilNetworkConfig() internal returns (NetworkConfig memory) {
        if (activeNetworkConfig.wETHPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator ethPriceFeed = new MockV3Aggregator(DECIMALS, ETH_PRICE_USD);
        ERC20Mock wETH = new ERC20Mock("wETH","wETH",msg.sender,1000e18);
        MockV3Aggregator btcPriceFeed = new MockV3Aggregator(DECIMALS, BTC_PRICE_USD);
        ERC20Mock wBTC = new ERC20Mock("wBTC","wBTC",msg.sender,1000e18);
        vm.stopBroadcast();
        console.log("Helper config_token deployer: ", msg.sender);
        return NetworkConfig({
            wETH: address(wETH),
            wBTC: address(wBTC),
            wETHPriceFeed: address(ethPriceFeed),
            wBTCPriceFeed: address(btcPriceFeed),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
}

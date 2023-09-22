//SPDX-License-Identiifer: MIT
pragma solidity ^0.8.21;

// // Arrange the functions to avoid wasting runs

// // 1. The total supply of TSC should be less than the total value of collateral
// // 2. Getter view functions should never revert <- evergreen

import {TestStableCoin} from "../../src/TestStableCoin.sol";
import {TSCEngine} from "../../src/TSCEngine.sol";
import {ERC20Mock} from "openzeppelin/mocks/ERC20Mock.sol";

contract HandlerTest {
    TestStableCoin tsc;
    TSCEngine tscEngine;
    ERC20Mock wETH;
    ERC20Mock wBTC;


    constructor(TestStableCoin _tsc, TSCEngine _tscEngine) {
        tsc = _tsc;
        tscEngine = _tscEngine;
        wETH = ERC20Mock(tscEngine.getCollateralToken(0));
        wBTC = ERC20Mock(tscEngine.getCollateralToken(1));
    }

    function depositCollateral(uint256 _collateralSeed, uint256 _amount) external {
        address collateral = address(_getCollateralToken(_collateralSeed));
        tscEngine.depositCollateral(collateral,_amount);
    }

    function _getCollateralToken(uint256 _seed) internal returns (ERC20Mock) {
        // even case: wETH
        if(_seed % 2 == 0){ 
            return wETH;
        } else {
            return wBTC;
        }
    }
}
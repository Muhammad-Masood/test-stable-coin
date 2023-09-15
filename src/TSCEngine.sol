// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20Burnable, ERC20} from "@openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {TestStableCoin} from "./TestStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

/**
 * @title Test Stable Coin Engine
 * @author Muhammad Masood
 * The system is designed to be minimal and maintains a peg or price of 1 token/TSC = 1$.
 * It is similar to DAI, if DAI had no governance, no fees, and was only backed by wETH and wBTC.
 *
 * Our TSC system should always be "over collateralized". At no point, the value of all collateral be <= the $ pegged value of all TSC.
 *
 * @notice This contract is the core of TSC system. It handles all the logic of mining and rendering TSC, as well as depositing and withdrawing collateral.
 * @notice This contract is very loosely based on MakerDao DSS(DAI) system.
 *
 *
 */

contract TSCEngine is ReentrancyGuard {
    error DSCEngine__TokenAdressAndPriceFeedAddressLengthMismatched();
    error DSCEngine__ZeroAmount();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TransferCollateralFailed();

    mapping(address token => address priceFeed) private s_priceFeed;
    mapping(address user => mapping(address token => uint256 amount)) private s_depositedCollateral;
    mapping(address user => uint256 amountTSCMinted) private s_TSCMinted;
    

    event CollateralDeposit(address indexed user, address indexed collateral, uint256);

    TestStableCoin private immutable i_tsc;

    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0) revert DSCEngine__ZeroAmount();
        _;
    }

    modifier isAllowedCollateral(address _token) {
        if (s_priceFeed[_token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedAddresses) {
        if (_tokenAddresses.length != _priceFeedAddresses.length) {
            revert DSCEngine__TokenAdressAndPriceFeedAddressLengthMismatched();
        }
        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            s_priceFeed[_tokenAddresses[i]] = _priceFeedAddresses[i];
        }
    }

    /**
     * @notice follows CEI
     * @param _collateralAdress address of the collateral i.e weth or wbtc that needs to be deposited.
     * @param _collateralAmount amount of the collateral to be deposited.
     */

    function depositCollateralAndMintTSC(address _collateralAdress, uint256 _collateralAmount)
        external
        moreThanZero(_collateralAmount)
        isAllowedCollateral(_collateralAdress)
        nonReentrant
    {
        s_depositedCollateral[msg.sender][_collateralAdress] += _collateralAmount;
        emit CollateralDeposit(msg.sender, _collateralAdress, _collateralAmount);
        bool success = IERC20(_collateralAdress).transferFrom(msg.sender, address(this), _collateralAmount);
        if (!success) revert DSCEngine__TransferCollateralFailed();
    }

    function redeemCollateralForTSC() external {}

    function burnTSC() external {}

    /**
     * 
     * @param _amount amount of TSC to be minted
     * @notice making sure the user doesn't mints $$$ (TSC) more than the ($$$) collateral deposited.
     * 
     */
    function mintTSC(uint256 _amount) external moreThanZero(_amount) {
        //check if user haven't minted more than the collateral deposited.
        s_TSCMinted[msg.sender] += _amount;
        _revertIfHealthFactorBroken(msg.sender);
    }

    function liquidate() external {}

    // function
    // function

    // Internal functions

    function _getAccountInfo(address _user) internal view returns (uint256 totalTSCMinted,uint256 totalCollateralValue) {
        totalTSCMinted = s_TSCMinted[_user];
        totalCollateralValue = getAccountCollateralValue(_user);
        return (totalTSCMinted,totalCollateralValue);
    }

    /**
     * returns how close to liquidation a user is.
     * If a user goes below 1, it will get liquidated. 
     */

    function _healthFactor(address _user) internal view returns (uint256) {
        (uint256 totalTSCMinted, uint256 totalCollateralValue) = _getAccountInfo(_user);
    }

    function _revertIfHealthFactorBroken(address _user)  internal view {

    }

    function getAccountCollateralValue()  external view returns (uint256 valueInUsd) {
        
        return 
    }
}

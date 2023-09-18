// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20Burnable, ERC20} from "@openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {TestStableCoin} from "./TestStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {console} from "lib/forge-std/src/console.sol";

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
    error DSCEngine__HealthFactorBroken();
    error DSCEngine__TransferMintFailed();
    error DSCEngine__TransferTSCFailed();

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 150;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;
    uint256 public immutable i_totalCollaterals;

    mapping(address token => address priceFeed) private s_priceFeed;
    mapping(address user => mapping(address token => uint256 amount)) private s_depositedCollateral;
    mapping(address user => uint256 amountTSCMinted) private s_TSCMinted;
    mapping(uint256 index => address token) private s_collateralTokens;

    event CollateralDeposit(address indexed user, address indexed collateralAddress, uint256 indexed amount);
    event RedeemCollateral(address indexed user, address indexed collateralAddress, uint256 indexed amount);

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

    constructor(uint256 _numberOfTokens, address[] memory _tokenAddresses, address[] memory _priceFeedAddresses) {
        uint256 _tokenAddressesLength = _tokenAddresses.length;
        if (_tokenAddressesLength != _priceFeedAddresses.length || _tokenAddressesLength != _numberOfTokens) {
            revert DSCEngine__TokenAdressAndPriceFeedAddressLengthMismatched();
        }
        i_totalCollaterals = _numberOfTokens;
        for (uint256 i = 0; i < i_totalCollaterals; i++) {
            s_priceFeed[_tokenAddresses[i]] = _priceFeedAddresses[i];
            s_collateralTokens[i] = _tokenAddresses[i];
        }
    }

    function depositCollateralAndMintTSC(address _collateralAdress, uint256 _collateralAmount, uint256 _mintAmount)
        external
    {
        depositCollateral(_collateralAdress, _collateralAmount);
        mintTSC(_mintAmount);
    }

    /**
     * @notice follows CEI
     * @param _collateralAdress address of the collateral i.e weth or wbtc that needs to be deposited.
     * @param _collateralAmount amount of the collateral to be deposited.
     */

    function depositCollateral(address _collateralAdress, uint256 _collateralAmount)
        public
        moreThanZero(_collateralAmount)
        isAllowedCollateral(_collateralAdress)
        nonReentrant
    {
        s_depositedCollateral[msg.sender][_collateralAdress] += _collateralAmount;
        emit CollateralDeposit(msg.sender, _collateralAdress, _collateralAmount);
        bool success = IERC20(_collateralAdress).transferFrom(msg.sender, address(this), _collateralAmount);
        if (!success) revert DSCEngine__TransferCollateralFailed();
    }

    function redeemCollateralForTSC(address _collateralAddress, uint256 _amountCollateral, uint256 _amountTSC) external {
        redeemCollateral(_collateralAddress, _amountCollateral);
        burnTSC(_amountTSC);
    }

    /**
     * In order to redeem:
     * Health factor should be > 1
     */

    function redeemCollateral(address _collateralAddress, uint256 _amountCollateral)
        public
        moreThanZero(_amountCollateral)
        isAllowedCollateral(_collateralAddress)
    {
        s_depositedCollateral[msg.sender][_collateralAddress] -= _amountCollateral;
        emit RedeemCollateral(msg.sender,_collateralAddress,_amountCollateral);
        bool success = IERC20(_collateralAddress).transfer(msg.sender,_amountCollateral);
        if(!success) revert DSCEngine__TransferCollateralFailed();
        _revertIfHealthFactorBroken(msg.sender);

    }

    function burnTSC(uint256 _amount) public moreThanZero(_amount) {
        s_TSCMinted[msg.sender] -= _amount;
        bool success = i_tsc.transferFrom(msg.sender,address(this),_amount);
        if(!success) revert DSCEngine__TransferTSCFailed();
        i_tsc.burn(_amount);
    }

    /**
     *
     * @param _amount amount of TSC to be minted
     * @notice making sure the user doesn't mints $$$ (TSC) more than the ($$$) collateral deposited.
     *
     */
    function mintTSC(uint256 _amount) public moreThanZero(_amount) {
        s_TSCMinted[msg.sender] += _amount;
        //check if user haven't minted more than the collateral deposited.
        _revertIfHealthFactorBroken(msg.sender);
        bool minted = i_tsc.mint(msg.sender, _amount);
        if (!minted) revert DSCEngine__TransferMintFailed();
    }

    function liquidate() external {}

    // function
    // function

    // Internal functions

    function _getAccountInfo(address _user)
        internal
        view
        returns (uint256 totalTSCMinted, uint256 totalCollateralValue)
    {
        totalTSCMinted = s_TSCMinted[_user];
        totalCollateralValue = getAccountCollateralValue(_user);
        return (totalTSCMinted, totalCollateralValue);
    }

    /**
     * returns how close to liquidation a user is.
     * If a user goes below 1, it will get liquidated.
     * We will be keeping collateralization ratio at 150%
     * This means if the user wants to mint 100 TSC, it will have to deposit 150$ as collateral 
     */

    function _healthFactor(address _user) internal view returns (uint256) {
        (uint256 totalTSCMinted, uint256 totalCollateralValue) = _getAccountInfo(_user);
        uint256 adjustedCollateral = (totalCollateralValue / (LIQUIDATION_THRESHOLD / LIQUIDATION_PRECISION));
        return (adjustedCollateral * PRECISION) / totalTSCMinted;
    }

    function _revertIfHealthFactorBroken(address _user) internal view {
        uint256 healthFactor = _healthFactor(_user);
        if (healthFactor < MIN_HEALTH_FACTOR) revert DSCEngine__HealthFactorBroken();
    }

    /**
     * returns the value in USD for whole collateral of the user.
     */

    function getAccountCollateralValue(address _user) public view returns (uint256 valueInUSD) {
        for (uint256 i = 0; i < i_totalCollaterals; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_depositedCollateral[_user][token];
            valueInUSD += getUSDValue(token, amount);
        }
        return valueInUSD;
    }

    /**
     * returns the value in USD for a any quantity of a token
     */

    function getUSDValue(address _token, uint256 _amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[_token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (((uint256(price) * ADDITIONAL_FEED_PRECISION) * _amount) / PRECISION);
    }

    function getDepositedCollateral(address _token) public view returns (uint256) {
        return s_depositedCollateral[msg.sender][_token];
    }

    function getTSCMinted() public view returns (uint256){
        return s_TSCMinted[msg.sender];
    }
}

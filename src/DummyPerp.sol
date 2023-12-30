// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "./oracle/AggregatorV3Interface.sol";
import {Pool} from "./Pool.sol";

    // @param account account the position's account
    // @param isLong whether the position is a long or short
    // @param sizeInUsd the position's size in USD (USDC)
    // @param sizeInTokens the position's size in tokens (BTC)
    // @param collateralAmount the amount of collateralToken for collateral
    struct Position {
        bool isOpen;
        bool isLong;
        uint256 sizeInTokens;
        uint256 sizeInUsd;
        uint256 collateralAmount;
    }

contract DummyPerp {
    using SafeERC20 for IERC20;

    error ZeroInput();
    error AlreadyExistPosition();
    error NotExistPosition();
    error ExceedMaximumLeverag();
    error ExceedMaximumUtilizeLiquidity();

    mapping(address => Position) public positions;

    IERC20 public asset;
    Pool pool;

    uint8 public constant MAXIMUM_LEVERAGE = 15;
    uint8 public constant MAX_UTILIZATIONPERCENTAGE = 80;
    uint public constant USDC_PRECISION = 1e6;
    uint public constant FEED_PRICE_PRECISION = 1e8;

    uint256 public totalOpenInterestLongInTokens;
    uint256 public totalOpenInterestLongInUsd;
    uint256 public totalOpenInterestShortInTokens;
    uint256 public totalOpenInterestShortInUsd;

    AggregatorV3Interface priceFeed;
    
    constructor(address _asset, address _priceFeed) {
        if(_asset == address(0) || _priceFeed == address(0)) revert ZeroInput();

        asset = IERC20(_asset);
        priceFeed = AggregatorV3Interface(_priceFeed);
        pool = new Pool(address(this), _asset);
    }


    modifier checkLiquidity() {
        _;
        if (
            totalOpenInterestShortInUsd > getMaxUtilizeLiquidity() ||
            totalOpenInterestLongInUsd > getMaxUtilizeLiquidity()
        ) {
            revert ExceedMaximumUtilizeLiquidity();
        }
    }

    function openPostion(uint256 _sizeInTokens, uint256 _collateralAmount, bool _isLong) external checkLiquidity {
        if (positions[msg.sender].isOpen) revert AlreadyExistPosition();
        if(_sizeInTokens == 0 || _collateralAmount == 0) revert ZeroInput();

        uint256 btcPrice = getBTCLatestPrice();
        uint256 sizeInUsd = (_sizeInTokens * btcPrice) / FEED_PRICE_PRECISION;
        if (sizeInUsd / _collateralAmount > MAXIMUM_LEVERAGE) revert ExceedMaximumLeverag();
        
        asset.safeTransferFrom(msg.sender, address(this), _collateralAmount);

        positions[msg.sender] = Position(
            true,
            _isLong,
            _sizeInTokens,
            sizeInUsd,
            _collateralAmount
        );

        if (_isLong) {
           totalOpenInterestLongInTokens += _sizeInTokens;
           totalOpenInterestLongInUsd += sizeInUsd;
        } else {
            totalOpenInterestShortInTokens += _sizeInTokens;
            totalOpenInterestShortInUsd += sizeInUsd;
        }
    }

    function increasePostion(uint256 _sizeInTokensAmout) external checkLiquidity {
        if(_sizeInTokensAmout == 0) revert ZeroInput();
        Position memory oldPosition = positions[msg.sender];
        if (!oldPosition.isOpen) revert NotExistPosition();

        uint256 btcPrice = getBTCLatestPrice();
        uint256 currentPostionValue = (btcPrice * oldPosition.sizeInTokens) / FEED_PRICE_PRECISION;
        uint256 newPostionSizeInUsd = currentPostionValue + (_sizeInTokensAmout * btcPrice) / FEED_PRICE_PRECISION;
        if (newPostionSizeInUsd / oldPosition.collateralAmount > MAXIMUM_LEVERAGE) revert ExceedMaximumLeverag();
    
        if (oldPosition.isLong) {
            totalOpenInterestLongInTokens += _sizeInTokensAmout;
           totalOpenInterestLongInUsd += newPostionSizeInUsd;
        } else {
            totalOpenInterestShortInTokens += _sizeInTokensAmout;
            totalOpenInterestShortInUsd += newPostionSizeInUsd;
        }

        positions[msg.sender] = Position(
            true,
            oldPosition.isOpen,
            oldPosition.sizeInTokens += _sizeInTokensAmout,
            newPostionSizeInUsd,
            oldPosition.collateralAmount
        );
        }

    function increaseCollateral(uint256 _collateralAmount) external {
        if(_collateralAmount == 0) revert ZeroInput();
        if(!positions[msg.sender].isOpen) revert NotExistPosition();

        asset.safeTransferFrom(msg.sender, address(this), _collateralAmount);
        positions[msg.sender].collateralAmount += _collateralAmount;
    }

    function getBTCLatestPrice() public view returns (uint256) {
        (
            /* uint80 roundID */,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function calulateTotalPnlOfLong() public view returns (int) {
        uint256 currentLongOpenInterestUsd = (getBTCLatestPrice() * totalOpenInterestShortInTokens) / FEED_PRICE_PRECISION;
        return int(currentLongOpenInterestUsd - totalOpenInterestLongInUsd);
    }

    function calulateTotalPnlOfShort() public view returns (int) {
        uint256 currentShortOpenInterestUsd = (getBTCLatestPrice() * totalOpenInterestShortInTokens) / FEED_PRICE_PRECISION;
        return int(totalOpenInterestShortInUsd - currentShortOpenInterestUsd);
    }

    function calulateTotalPnLOfTraders() public view returns (int) {
        return calulateTotalPnlOfLong() + calulateTotalPnlOfShort();
    }

    function calculatePnLOfTrader(address who) public view returns (int) {
        Position memory _position = positions[who];
        uint256 currentValue = (getBTCLatestPrice() * _position.sizeInTokens) / FEED_PRICE_PRECISION;
        int PnL = 0;

        if(!_position.isOpen) {
            return PnL;
        } else if(_position.isLong) {
            PnL = int(currentValue - _position.sizeInUsd);
        } else {
            PnL = int(_position.sizeInUsd - currentValue);
        }
        return PnL;
    }
    function calculateMaximumPossibleProfit() public view returns (uint256) {
        uint256 btcPrice = getBTCLatestPrice();
        return totalOpenInterestShortInUsd + (totalOpenInterestLongInTokens * btcPrice) / FEED_PRICE_PRECISION;
    }

    function getMaxUtilizeLiquidity() public view returns (uint256) {
        return (pool.totalAssets() * MAX_UTILIZATIONPERCENTAGE / 100);
    }
}
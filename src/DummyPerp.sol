// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "./oracle/AggregatorV3Interface.sol";


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

    error AlreadyExistPosition();
    error ExceedingMaximumLeverag();

    mapping(address => Position) public positions;

    IERC20 public asset;

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
        asset = IERC20(_asset);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }


    function openPostion(uint256 _sizeInTokens, uint256 _collateralAmount, bool _isLong) external {
        if (positions[msg.sender].isOpen) revert AlreadyExistPosition();
        require(_sizeInTokens != 0 && _collateralAmount != 0, "Invalid Param");
        uint256 btcPrice = getBTCLatestPrice();
        uint256 sizeInUsd = (_sizeInTokens * btcPrice) / FEED_PRICE_PRECISION;
        if (sizeInUsd / _collateralAmount > MAXIMUM_LEVERAGE) revert ExceedingMaximumLeverag();
        
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

    function closePosition() external {
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

    function calculatePnL(address who) public view returns (int) {
        Position memory position = positions[who];
        uint256 currentValue = getBTCLatestPrice() * position.sizeInTokens / FEED_PRICE_PRECISION;
        int PnL = 0;

        if(!position.isOpen) {
            return PnL;
        } else if(position.isLong) {
            PnL = int(currentValue - position.sizeInUsd);
        } else {
            PnL = int(position.sizeInUsd - currentValue);
        }
        return PnL;
    }

    function calculateMaximumPossibleProfit() public view returns (uint256) {
        uint256 btcPrice = getBTCLatestPrice();
        return totalOpenInterestShortInUsd + (totalOpenInterestLongInTokens * btcPrice) / FEED_PRICE_PRECISION;
    }
}
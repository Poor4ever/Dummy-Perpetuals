// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {AggregatorV3Interface} from "./oracle/AggregatorV3Interface.sol";
import {Pool} from "./Pool.sol";

    // @param isOpen position's status
    // @param isLong whether the position is a long or short
    // @param sizeInUsd the position's size in USD (USDC)
    // @param sizeInTokens the position's size in tokens (BTC)
    // @param collateralAmount the amount of collateralToken for collateral
    // @param borrowingFees accumulated borrowing fees
    // @param lastBorrowFeeUpdatedTimestamp last Update timestamp for borrowing fees 
    struct Position {
        bool isOpen;
        bool isLong;
        uint256 sizeInTokens;
        uint256 sizeInUsd;
        uint256 collateralAmount;
        uint256 borrowingFees;
        uint256 lastBorrowFeeUpdatedTimestamp;
    }

contract DummyPerp {
    using SafeERC20 for IERC20;
    using SignedMath for int;

    error ZeroInput();
    error AlreadyExistPosition();
    error NotExistPosition();
    error ExceedMaximumLeverage();
    error ExceedMaximumUtilizeLiquidity();
    error InsufficientCollateral();
    error NonLiquidable();

    mapping(address => Position) public positions;

    IERC20 public asset;
    Pool public pool;

    uint public constant BASIS_POINTS_DIVISOR = 10000;
    uint public constant MAXIMUM_LEVERAGE = 15 * BASIS_POINTS_DIVISOR;
    uint8 public constant MAX_UTILIZATIONPERCENTAGE = 80;
    uint public constant USDC_PRECISION = 1e6;
    uint public constant FEED_PRICE_PRECISION = 1e8; 
    uint public constant LIQUIDATION_FEE_PERCENTAGE = 10;
    uint public constant BORROWING_FEE_PRECISION = 1e30;
    uint public constant BORROWING_PER_SHARE_PER_SECOND = BORROWING_FEE_PRECISION / 315_360_000;
    
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
        uint256 maxUtilizeLiquidity = getMaxUtilizeLiquidity();
        if (
            totalOpenInterestShortInUsd * USDC_PRECISION > maxUtilizeLiquidity ||
            totalOpenInterestLongInUsd * USDC_PRECISION > maxUtilizeLiquidity
        ) {
            revert ExceedMaximumUtilizeLiquidity();
        }
    }

    function openPosition(uint256 _sizeInTokensAmount, uint256 _collateralAmount, bool _isLong) external checkLiquidity {
        if (positions[msg.sender].isOpen) revert AlreadyExistPosition();
        if(_sizeInTokensAmount == 0 || _collateralAmount == 0) revert ZeroInput();

        uint256 btcPrice = getBTCLatestPrice();
        uint256 sizeInUsd = (_sizeInTokensAmount * btcPrice) / FEED_PRICE_PRECISION;
        
        
        asset.safeTransferFrom(msg.sender, address(this), _collateralAmount);

        _increaseTotalOpenInterest(_sizeInTokensAmount, sizeInUsd, _isLong);

        positions[msg.sender] = Position(
            true,
            _isLong,
            _sizeInTokensAmount,
            sizeInUsd,
            _collateralAmount,
            0,
            block.timestamp
        );

        if(isExceedMaxLeverage(msg.sender)) revert ExceedMaximumLeverage();
    }

    function increasePositionSize(uint256 _sizeInTokensAmount) external checkLiquidity {
        if(_sizeInTokensAmount == 0) revert ZeroInput();
        Position memory oldPosition = positions[msg.sender];
        if (!oldPosition.isOpen) revert NotExistPosition();

        uint256 sizeInUsd = (_sizeInTokensAmount * getBTCLatestPrice()) / FEED_PRICE_PRECISION;

        _updateborrowingFees(msg.sender);
        _increaseTotalOpenInterest(_sizeInTokensAmount, sizeInUsd, oldPosition.isLong);

        positions[msg.sender].sizeInTokens += _sizeInTokensAmount;
        positions[msg.sender].sizeInUsd += sizeInUsd;

        if(isExceedMaxLeverage(msg.sender)) revert ExceedMaximumLeverage();
    }

    function increaseCollateral(uint256 _collateralAmount) external {
        if(_collateralAmount == 0) revert ZeroInput();
        if(!positions[msg.sender].isOpen) revert NotExistPosition();

        asset.safeTransferFrom(msg.sender, address(this), _collateralAmount);
        positions[msg.sender].collateralAmount += _collateralAmount;
    }


    function decreasePositionSize(uint256 _sizeInTokensAmout) external {
        if(_sizeInTokensAmout == 0) revert ZeroInput();
        if(!positions[msg.sender].isOpen) revert NotExistPosition();
        Position memory oldPosition = positions[msg.sender];

        int totalPnl = calculatePnLOfTrader(msg.sender);
        int realizedPnl = totalPnl * int(_sizeInTokensAmout) / int(oldPosition.sizeInTokens);
        uint256 sizeInUsd = (_sizeInTokensAmout * getBTCLatestPrice()) / FEED_PRICE_PRECISION;
        
        _updateborrowingFees(msg.sender);
        _decreaseTotalOpenInterest(sizeInUsd, _sizeInTokensAmout, oldPosition.isLong);
       
        positions[msg.sender].sizeInTokens -= _sizeInTokensAmout;
       
        positions[msg.sender].sizeInUsd -= sizeInUsd;
        if(isExceedMaxLeverage(msg.sender)) revert InsufficientCollateral();
        
        if(realizedPnl > 0) {
            asset.safeTransfer(msg.sender, uint256(realizedPnl) * USDC_PRECISION);
        } else {
            asset.safeTransfer(address(pool), realizedPnl.abs() * USDC_PRECISION);
        }
    }

    function decreasePositionCollateral(uint256 _collateralAmount) external {
        if (_collateralAmount == 0) revert ZeroInput();
        if(!positions[msg.sender].isOpen) revert NotExistPosition();

        uint currentBtcPrice = getBTCLatestPrice();
        positions[msg.sender].collateralAmount -= _collateralAmount;
       
        if(isExceedMaxLeverage(msg.sender)) revert InsufficientCollateral();

        asset.safeTransfer(msg.sender, _collateralAmount);
    }

    function liquidatePosition(address _account) external {
        if(!positions[msg.sender].isOpen) revert NotExistPosition();
        if(!isExceedMaxLeverage(_account)) revert NonLiquidable();

        _updateborrowingFees(_account);

        Position memory tempPositon = positions[_account];

        int pnl = calculatePnLOfTrader(_account);
        uint256 loss = pnl.abs() * USDC_PRECISION;
        uint256 liquditionFee;

        if(tempPositon.collateralAmount < loss) {
            liquditionFee = (tempPositon.collateralAmount * LIQUIDATION_FEE_PERCENTAGE) / 100;
            asset.safeTransfer(msg.sender, liquditionFee);
            asset.safeTransfer(address(pool), tempPositon.collateralAmount - liquditionFee);
        } else if (tempPositon.collateralAmount < liquditionFee + tempPositon.borrowingFees + loss) {
                asset.safeTransfer(msg.sender, liquditionFee);
                asset.safeTransfer(address(pool), tempPositon.collateralAmount - liquditionFee);
            } else{
                liquditionFee = (loss * LIQUIDATION_FEE_PERCENTAGE) / 100;
                asset.safeTransfer(msg.sender, liquditionFee);
                asset.safeTransfer(address(pool), loss - liquditionFee);
                asset.safeTransfer(address(pool), tempPositon.borrowingFees);
                asset.safeTransfer(_account, (tempPositon.collateralAmount - loss - tempPositon.borrowingFees));
            }
       
        delete positions[_account];
        }

        


    function isExceedMaxLeverage(address _account) view public returns(bool) {
        Position memory tempPositon = positions[_account];
        
        int pnl = calculatePnLOfTrader(_account);
        if(pnl > 0) {
            tempPositon.collateralAmount += uint256(pnl);
        } else {
            tempPositon.collateralAmount -= pnl.abs();
        }

        if(tempPositon.borrowingFees > tempPositon.collateralAmount) {
            return true;
        }

        return ((tempPositon.collateralAmount - tempPositon.borrowingFees) * MAXIMUM_LEVERAGE)  < (tempPositon.sizeInTokens * getBTCLatestPrice() * BASIS_POINTS_DIVISOR * USDC_PRECISION) / FEED_PRICE_PRECISION ? true : false;
    }

    function _increaseTotalOpenInterest(uint256 _sizeInTokens, uint256 _sizeInUsd, bool _isLong) internal {
        if(_isLong) {
            totalOpenInterestLongInTokens += _sizeInTokens;
            totalOpenInterestLongInUsd += _sizeInUsd;
        } else {
            totalOpenInterestShortInTokens += _sizeInTokens;
            totalOpenInterestShortInUsd += _sizeInUsd;
        }
    }


    function _decreaseTotalOpenInterest(uint256 _sizeInTokens, uint256 _sizeInUsd, bool _isLong) internal {
        if(_isLong) {
            totalOpenInterestLongInTokens -= _sizeInTokens;
            totalOpenInterestLongInUsd -= _sizeInUsd;
        } else {
            totalOpenInterestShortInTokens -= _sizeInTokens;
            totalOpenInterestShortInUsd -= _sizeInUsd;
        }
    }


    function _updateborrowingFees(address _account) internal {
        Position memory tempPositon = positions[_account];
        if(block.timestamp > tempPositon.lastBorrowFeeUpdatedTimestamp) {
            uint secondsSincePositionUpdated = block.timestamp - tempPositon.lastBorrowFeeUpdatedTimestamp;
            uint borrowing_fee = tempPositon.sizeInUsd * secondsSincePositionUpdated * BORROWING_FEE_PRECISION;
            positions[_account].borrowingFees += borrowing_fee;
            positions[_account].lastBorrowFeeUpdatedTimestamp = block.timestamp;
        }
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
        uint256 currentLongOpenInterestUsd = (getBTCLatestPrice() * totalOpenInterestLongInTokens) / FEED_PRICE_PRECISION;
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
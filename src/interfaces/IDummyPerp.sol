pragma solidity ^0.8.20;

interface IDummyPerp {
    error AddressEmptyCode(address target);
    error AddressInsufficientBalance(address account);
    error AlreadyExistPosition();
    error ExceedMaximumLeverag();
    error FailedInnerCall();
    error NotExistPosition();
    error SafeERC20FailedOperation(address token);
    error ZeroInput();

    function FEED_PRICE_PRECISION() external view returns (uint256);
    function MAXIMUM_LEVERAGE() external view returns (uint8);
    function MAX_UTILIZATIONPERCENTAGE() external view returns (uint8);
    function USDC_PRECISION() external view returns (uint256);
    function asset() external view returns (address);
    function calculateMaximumPossibleProfit() external view returns (uint256);
    function calculatePnLOfTrader(address who) external view returns (int256);
    function calulateTotalPnLOfTraders() external view returns (int256);
    function calulateTotalPnlOfLong() external view returns (int256);
    function calulateTotalPnlOfShort() external view returns (int256);
    function getBTCLatestPrice() external view returns (uint256);
    function increaseCollateral(uint256 _collateralAmount) external;
    function increasePostion(uint256 _sizeInTokensAmout) external;
    function openPostion(uint256 _sizeInTokens, uint256 _collateralAmount, bool _isLong) external;
    function positions(address)
        external
        view
        returns (bool isOpen, bool isLong, uint256 sizeInTokens, uint256 sizeInUsd, uint256 collateralAmount);
    function totalOpenInterestLongInTokens() external view returns (uint256);
    function totalOpenInterestLongInUsd() external view returns (uint256);
    function totalOpenInterestShortInTokens() external view returns (uint256);
    function totalOpenInterestShortInUsd() external view returns (uint256);
}
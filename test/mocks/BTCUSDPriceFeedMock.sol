// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract BTCUSDPriceFeedMock {

    int256 btcPrice;

    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        return (0, btcPrice, block.timestamp, block.timestamp, 0);
    }

    function changeBTCPrice(int _pric) external {
        btcPrice = _pric;
    }
}
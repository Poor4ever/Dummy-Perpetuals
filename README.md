# Dummy Perpetuals

![Dummy-Perpetuals](./images/Dummy-Perpetuals.jpg)

## About

This is an implementation of [Mission #1](https://guardianaudits.notion.site/Mission-1-Perpetuals-028ca44faa264d679d6789d5461cfb13)  and [Mission #2](https://guardianaudits.notion.site/Mission-2-Wen-Perps-e259c006c442448ea09844b080f66e9a) for the [Gateway Web3 Security Course](https://guardianaudits.notion.site/guardianaudits/Gateway-Free-Web3-Security-Course-574f4d819c144d7895cda6d61ba26503).

## Overview

The protocol allows users to use USDC as collateral to open long or short positions with a maximum leverage of up to 15x.

## ToDo List
### Mission #1

The first mission focuses on implementing roughly 50% of the basic functionality of a decentralized perpetuals protocol.

| functionality                                                | implementation | Testing |
| ------------------------------------------------------------ | -------------- | ------- |
| Liquidity Providers can deposit and withdraw liquidity.      | ✅              | ✅       |
| A way to get the realtime price of the asset being traded.   | ✅              | ✅       |
| Traders can open a perpetual position for BTC, with a given size and collateral. | ✅              |         |
| Traders can increase the size of a perpetual position.       | ✅              |         |
| Traders can increase the collateral of a perpetual position. | ✅              |         |
| Traders cannot utilize more than a configured percentage of the deposited liquidity. | ✅              |         |
| Liquidity providers cannot withdraw liquidity that is reserved for positions. | ✅              |         |

### Mission #2

The second mission focuses on implementing the rest of the basic functionality of a decentralized perpetuals protocol.

| functionality                                                | implementation  | Testing |
| ------------------------------------------------------------ | --------------- | ------- |
| Traders can decrease the size of their position and realize a proportional amount of their PnL. | ✅               |         |
| Traders can decrease the collateral of their position.       | ✅               |         |
| A liquidatorFee is taken from the position’s remaining collateral upon liquidation with the liquidate function and given to the caller of the liquidate function. | ✅               |         |
| It is up to you whether the liquidatorFee is a percentage of the position’s remaining collateral or the position’s size, you should have a reasoning for your decision documented in the README.md. | position’s size |         |
| Traders can never modify their position such that it would make the position liquidatable. | ✅               |         |
| Traders are charged a borrowingFee which accrues as a function of their position size and the length of time the position is open. |                 |         |
| Traders are charged a positionFee from their collateral whenever they change the size of their position, the positionFee is a percentage of the position size delta (USD converted to collateral token). — Optional/Bonus |                 |         |



## Know Issues 

Precision Loss
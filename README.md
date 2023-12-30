# Dummy Perpetuals

![Dummy-Perpetuals](./images/Dummy-Perpetuals.jpg)

## About

This is an implementation of [Mission #1](https://guardianaudits.notion.site/Mission-1-Perpetuals-028ca44faa264d679d6789d5461cfb13) for the [Gateway Web3 Security Course](https://guardianaudits.notion.site/guardianaudits/Gateway-Free-Web3-Security-Course-574f4d819c144d7895cda6d61ba26503)

The first mission focuses on implementing roughly 50% of the basic functionality of a decentralized perpetuals protocol.

## Overview

The protocol allows users to use USDC as collateral to open long or short positions with a maximum leverage of up to 15x

## ToDo List

| functionality                                                | implementation | Testing |
| ------------------------------------------------------------ | -------------- | ------- |
| Liquidity Providers can deposit and withdraw liquidity.      |                |         |
| A way to get the realtime price of the asset being traded.   | ✅              |         |
| Traders can open a perpetual position for BTC, with a given size and collateral. | ✅              |         |
| Traders can increase the size of a perpetual position.       |                |         |
| Traders can increase the collateral of a perpetual position. |                |         |
| Traders cannot utilize more than a configured percentage of the deposited liquidity. |                |         |
| Liquidity providers cannot withdraw liquidity that is reserved for positions. |                |         |

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {DummyPerp} from "../src/DummyPerp.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DummyPerpTest is Test {
    DummyPerp public dummyPerp;
    ERC20Mock public asset;

    uint256 mainnetFork;
    address constant BTC_USD_PRICE_FEED = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    
    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        asset = new ERC20Mock();
        dummyPerp = new DummyPerp(address(asset), BTC_USD_PRICE_FEED);
    }


    function testOraclePriceFeed() public {
        uint256 btcPrice = dummyPerp.getBTCLatestPrice();
        console2.log(btcPrice);
    }
}
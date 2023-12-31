// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DummyPerp} from "../src/DummyPerp.sol";
import {Pool} from "../src/Pool.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {BTCUSDPriceFeedMock as PriceFeed} from "./mocks/BTCUSDPriceFeedMock.sol";

contract DummyPerpTest is Test {
    DummyPerp public dummyPerp;
    Pool public pool;
    ERC20Mock public asset;
    PriceFeed public priceFeed;
 
    // uint256 mainnetFork;
    // address constant BTC_USD_PRICE_FEED = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    // string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    address[] traders;
    address[] liquidityProviders;

    function setUp() public {
        // mainnetFork = vm.createFork(MAINNET_RPC_URL);
        // vm.selectFork(mainnetFork);
        asset = new ERC20Mock();
        priceFeed = new PriceFeed();
        dummyPerp = new DummyPerp(address(asset), address(priceFeed));
        pool = Pool(dummyPerp.pool());
        makeAddressArray(5);
    }

    function testDepositandWithdraw(uint amount) public {
        vm.assume(amount < type(uint256).max / liquidityProviders.length);

        for (uint index; index < liquidityProviders.length; index++) {
            address currentTrader = liquidityProviders[index];
            deal(address(asset), currentTrader, amount);
            vm.startPrank(currentTrader);
            asset.approve(address(pool), amount);
            pool.deposit(amount, currentTrader);
            vm.stopPrank();
        }

        for (uint index; index < liquidityProviders.length; index++) {
            address currentTrader = liquidityProviders[index];
            vm.startPrank(currentTrader);
            pool.withdraw(amount, currentTrader, currentTrader);
            vm.stopPrank();
            assertEq(asset.balanceOf(currentTrader), amount);
        }
    }

    function testOpenPostion(uint sizeInTokenAmount, uint collateralAmount, bool isLong) public {
        sizeInTokenAmount = bound(sizeInTokenAmount, 1, 10000);
        int btcPrice = 50000e8;
        uint collateralAmountMin = uint(btcPrice) * sizeInTokenAmount * dummyPerp.MAXIMUM_LEVERAGE();
   
        uint maxUtilizeliquidity = collateralAmountMin * dummyPerp.MAX_UTILIZATIONPERCENTAGE();
        
        vm.assume(collateralAmount > collateralAmountMin);
        liquidityProvidersDeposit(liquidityProviders, collateralAmountMin / liquidityProviders.length + 1);

        priceFeed.changeBTCPrice(btcPrice);

        address treader = traders[0];
        asset.mint(treader, collateralAmount);
        vm.startPrank(treader);
        asset.approve(address(dummyPerp), collateralAmount);
        dummyPerp.openPostion(sizeInTokenAmount, collateralAmount, isLong);
        vm.stopPrank();
    }


    function testOraclePriceFeed(int pric) public {
        int price = bound(pric,43000, 45000) * 1e8;
        priceFeed.changeBTCPrice(price);
        uint256 btcPrice = dummyPerp.getBTCLatestPrice();
        console.log(btcPrice);
    }

    function makeAddressArray(uint Num) public {
        traders = new address[](Num);
        liquidityProviders = new address[](Num);
        
        for (uint160 index; index < Num; index++) {
            traders[index] = address(index + 666);
            liquidityProviders[index] = address(index + 999);
        }
    }

    function liquidityProvidersDeposit(address[] memory _liquidityProviders, uint amount) internal {
        for (uint index; index < _liquidityProviders.length; index++) {
            address currentTrader = _liquidityProviders[index];
            deal(address(asset), currentTrader, amount);
            vm.startPrank(currentTrader);
            asset.approve(address(pool), amount);
            pool.deposit(amount, currentTrader);
            vm.stopPrank();
        }
    }
}
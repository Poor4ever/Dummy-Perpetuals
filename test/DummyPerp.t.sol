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

    function testOpenPosition(uint sizeInTokenAmount, uint collateralAmount, uint depositLiquidityAmount, bool isLong) public {  
        sizeInTokenAmount = bound(sizeInTokenAmount, 1, type(uint24).max);
        vm.assume(depositLiquidityAmount < type(uint160).max);
        vm.assume(collateralAmount > 0 &&  collateralAmount < type(uint256).max / dummyPerp.MAXIMUM_LEVERAGE());
        _liquidityProviderDeposit(liquidityProviders[0], depositLiquidityAmount);
        int btcPrice = 50000;
        priceFeed.changeBTCPrice(btcPrice * 1e8);
        uint collateralAmountMin = uint(btcPrice) * sizeInTokenAmount * dummyPerp.MAXIMUM_LEVERAGE();
        uint postionSizeInusdc = uint(btcPrice) * sizeInTokenAmount * dummyPerp.BASIS_POINTS_DIVISOR() * dummyPerp.USDC_PRECISION();
        uint maxUtilizeliquidity = pool.totalAssets() * dummyPerp.MAX_UTILIZATIONPERCENTAGE() * dummyPerp.BASIS_POINTS_DIVISOR() / 100;
        uint maxpositionValue = collateralAmount * dummyPerp.MAXIMUM_LEVERAGE();
 


        address trader = traders[0];
        asset.mint(trader, collateralAmount);
        vm.startPrank(trader);
        asset.approve(address(dummyPerp), collateralAmount);
        if(postionSizeInusdc > maxUtilizeliquidity || postionSizeInusdc > maxpositionValue) vm.expectRevert();
        dummyPerp.openPosition(sizeInTokenAmount, collateralAmount, isLong);
        vm.stopPrank();

        (bool isOpen, 
        bool isLong, 
        uint256 sizeInTokens, 
        uint256 sizeInUsd, 
        uint256 collateralAmount,
         ,
        
        ) = dummyPerp.positions(trader);
        if (isOpen) {
            assertLe(sizeInUsd * dummyPerp.USDC_PRECISION(), collateralAmount * 15);
            assertLe(sizeInUsd * dummyPerp.USDC_PRECISION(), maxpositionValue);
        }
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

    function _liquidityProviderDeposit(address _liquidityProvider, uint amount) internal {
        deal(address(asset), _liquidityProvider, amount);
        vm.startPrank(_liquidityProvider);
        asset.approve(address(pool), amount);
        pool.deposit(amount, _liquidityProvider);
        vm.stopPrank();
    }

    function _liquidityProvidersDeposit(address[] memory _liquidityProviders, uint amount) internal {
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
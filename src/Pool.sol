// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IDummyPerp} from "./interfaces/IDummyPerp.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract Pool is ERC4626 {
    IDummyPerp dummyPerp;
    constructor(address _dummyPerp, address _asset) ERC4626(IERC20(_asset)) ERC20("DummtLPShare","DLS") {
        dummyPerp = IDummyPerp(_dummyPerp);
    }

    function maxWithdraw(address liquidityProvider) public view override returns (uint256) {
        uint256 _totalAssets = totalAssets();
        uint256 withdrawableAmount = _convertToAssets(balanceOf(liquidityProvider), Math.Rounding.Ceil);
        uint256 lockupProfitAmount = (dummyPerp.calculateMaximumPossibleProfit() * dummyPerp.MAX_UTILIZATIONPERCENTAGE()) / 100;
        if (_totalAssets < lockupProfitAmount) {
            return 0;
        } else if(withdrawableAmount < lockupProfitAmount) {
            return withdrawableAmount;
        } else {
            return _totalAssets - lockupProfitAmount;
        }
    }

    function maxRedeem(address liquidityProvider) public view override returns (uint256) {
        return convertToShares(maxWithdraw(liquidityProvider));
    }
}
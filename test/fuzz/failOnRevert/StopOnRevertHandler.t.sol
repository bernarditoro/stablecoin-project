// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {DecentralisedStableCoin} from "../../../src/DecentralisedStableCoin.sol";
import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";

contract StopOnRevertHandler is Test {
    using EnumerableSet for EnumerableSet.AddressSet;

    DSCEngine public dscEngine;
    DecentralisedStableCoin public dsc;
    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;
    MockERC20 public weth;
    MockERC20 public wbtc;

    constructor(DSCEngine _dscEngine, DecentralisedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = MockERC20(collateralTokens[0]);
        wbtc = MockERC20(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(weth)));
        btcUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(wbtc)));
    }

    // FUNCTIONS TO INTERACT WITH

    // DSCEngine
    function mintAndDepositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        amountCollateral = bound(amountCollateral, 1, type(uint96).max);
        MockERC20 collateral = _getCollateralFromSeed(collateralSeed);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        MockERC20 collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateral = dscEngine.getUserCollateralBalance(msg.sender, address(collateral));

        amountCollateral = bound(amountCollateral, 0, maxCollateral);
        if (amountCollateral == 0) {
            return;
        }

        vm.prank(msg.sender);
        dscEngine.redeemCollateral(address(collateral), amountCollateral);
    }

    function burnDsc(uint256 amountDsc) public {
        // Must burn more than 0
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        if (amountDsc == 0) {
            return;
        }
        vm.startPrank(msg.sender);
        dsc.approve(address(dscEngine), amountDsc);
        dscEngine.burnDsc(amountDsc);
        vm.stopPrank();
    }

    function liquidate(uint256 collateralSeed, address userToBeLiquidated, uint256 debtToCover) public {
        uint256 userHealthFactor = dscEngine.getHealthFactor(userToBeLiquidated);
        if (userHealthFactor >= 1) {
            return;
        }
        debtToCover = bound(debtToCover, 1, uint256(type(uint96).max));
        MockERC20 collateral = _getCollateralFromSeed(collateralSeed);
        dscEngine.liquidate(address(collateral), userToBeLiquidated, debtToCover);
    }
    // End DSCEngine

    // DecentralisedStableCoin
    function transferDsc(uint256 amountDsc, address to) public {
        if (to == address(0)) {
            to = address(1);
        }

        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        vm.prank(msg.sender);
        dsc.transfer(to, amountDsc);
    }
    // End DecentralisedStableCoin

    // Aggregator
    function updateCollateralPrice(uint96 newPrice, uint256 collateralSeed) public {
        int256 intNewPrice = int256(uint256(newPrice));
        MockERC20 collateral = _getCollateralFromSeed(collateralSeed);
        MockV3Aggregator priceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(collateral)));

        priceFeed.updateAnswer(intNewPrice);
    }
    // End Aggregator

    // Helper Functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (MockERC20) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
    // End Helper Functions
}

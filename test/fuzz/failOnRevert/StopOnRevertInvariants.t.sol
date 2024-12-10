// SPDX-License-Identifier: MIT

/*
 * First, identify the invariants (values/conditions that should always hold for the lifetime of the contract)
 *
 * 1. The total supply of DSC should be less than the total value of collateral
 * 2. Getter view functions should never revert <- evergreen invariant

 */

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {DecentralisedStableCoin} from "../../../src/DecentralisedStableCoin.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {StopOnRevertHandler} from "./StopOnRevertHandler.t.sol";
import {DeployDSC} from "../../../script/DeployDSC.s.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {console} from "forge-std/console.sol";

contract StopOnRevertInvariants is StdInvariant, Test {
    DSCEngine public dscEngine;
    DecentralisedStableCoin public dsc;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;

    StopOnRevertHandler public handler;

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();
        handler = new StopOnRevertHandler(dscEngine, dsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThatTotalSupplyDollars() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 wethDeposted = MockERC20(weth).balanceOf(address(dscEngine));
        uint256 wbtcDeposited = MockERC20(wbtc).balanceOf(address(dscEngine));

        uint256 wethValue = dscEngine.getUsdValue(weth, wethDeposted);
        uint256 wbtcValue = dscEngine.getUsdValue(wbtc, wbtcDeposited);

        console.log("wethValue: %s", wethValue);
        console.log("wbtcValue: %s", wbtcValue);

        assert(wethValue + wbtcValue >= totalSupply);
    }
}

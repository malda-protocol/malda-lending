// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Operator} from "src/Operator/Operator.sol";

import {DeployBaseRelease} from "../../../deployers/DeployBaseRelease.sol";

contract LiquidationTestLinea is DeployBaseRelease {
    using stdJson for string;

    address internal constant LIQUIDATOR = 0xB819A871d20913839c37f316Dc914b0570bfc0eE;
    address internal constant BORROWER = 0xCde13fF278bc484a09aDb69ea1eEd3cAf6Ea4E00;
    address internal constant MARKET = 0x6AECeD8e67964Eb6d0Ae7B159D27eF07F6c11b99; //weth
    address internal constant OPERATOR = 0x4bbd2B599425026b8A504816D8A043636e2D7Ec7;
    address[] internal marketList;

    function setUp() public override {
        configPath = "deployment-config-release.json";
        super.setUp();
    }

    function run() public {
        uint256 key = vm.envUint("PRIVATE_KEY");
        uint256 borrowerKey = vm.envUint("BORROWER_KEY");

        mErc20Host m = mErc20Host(MARKET);
        address underlying = m.underlying();

        console.log("underlying: ", underlying);

        // set minBorrow to allow test
        address[] memory mTokens = new address[](1);
        uint256[] memory sizes = new uint256[](1);
        mTokens[0] = MARKET;
        sizes[0] = 1;
        console.log("Setting min borrow size ...");
        vm.startBroadcast(key);
        Operator(OPERATOR).setBorrowSizeMin(mTokens, sizes);
        vm.stopBroadcast();

        // approve
        console.log("Approving underlying...");
        vm.startBroadcast(borrowerKey);
        IERC20Metadata(underlying).approve(address(m), 0.00001e18);
        vm.stopBroadcast();

        // add collateral
        console.log("Adding collateral...");
        vm.startBroadcast(borrowerKey);
        m.mint(0.00001e18, BORROWER, 0);
        vm.stopBroadcast();

        // borrow
        console.log("Borrowing...");
        vm.startBroadcast(borrowerKey);
        m.borrow(0.029e6);
        vm.stopBroadcast();

        // set collateral factor to 1%
        console.log("Setting collateral factor...");
        vm.startBroadcast(key);
        Operator(OPERATOR).setCollateralFactor(MARKET, 1);
        vm.stopBroadcast();

        // approve for liquidation
        console.log("Approving underlying for liquidation...");
        vm.startBroadcast(key);
        IERC20Metadata(underlying).approve(address(m), 1e18);
        vm.stopBroadcast();

        // liquidate
        console.log("Liquidating...");
        vm.startBroadcast(key);
        m.liquidate(BORROWER, 0.01e6, MARKET);
        vm.stopBroadcast();

        // reset collateral factor
        console.log("Reset collateral factor...");
        uint256 collateralFactor = 830000000000000000;
        vm.startBroadcast(key);
        Operator(OPERATOR).setCollateralFactor(MARKET, collateralFactor);
        vm.stopBroadcast();

        // reset borrow size
        console.log("Reset min borrow size...");
        sizes[0] = 0.000125e18;
        vm.startBroadcast(key);
        Operator(OPERATOR).setBorrowSizeMin(mTokens, sizes);
        vm.stopBroadcast();
    }
}

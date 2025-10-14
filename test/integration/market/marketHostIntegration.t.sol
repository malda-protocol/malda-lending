// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Vm} from "forge-std/Vm.sol";


import { mErc20Host } from "src/mToken/host/mErc20Host.sol";
import { JumpRateModelV5 } from "src/interest/JumpRateModelV5.sol";

import { mTokenConfiguration } from "src/mToken/mTokenConfiguration.sol";
import { mTokenStorage } from "src/mToken/mTokenStorage.sol";
import { mToken } from "src/mToken/mToken.sol";

import { Operator } from "src/Operator/Operator.sol";


import "forge-std/console2.sol";
interface IERC20 {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}


contract marketHostIntegration is Test {
    // ---------- Constants ----------
    address public constant MARKET_18DECIMALS = 0xa31963C753f277f7d82d98F56b2C374256925eB7; //wrsETH

    uint256 lineaFork;
    uint256 chainIdOnFork;
    address ownerOnChain;

    JumpRateModelV5 newInterestModel;
    mErc20Host market18Decimals;
    IERC20 asset18Decimals;

    function setUp() public {
        string memory rpc = vm.envString("LINEA_RPC_URL");
        lineaFork = vm.createSelectFork(rpc, 24326770);
        chainIdOnFork = block.chainid;

        market18Decimals = mErc20Host(MARKET_18DECIMALS);
        asset18Decimals = IERC20(address(market18Decimals.underlying()));
        ownerOnChain = market18Decimals.admin(); // same owner for all markets

        newInterestModel = new JumpRateModelV5(31536000, 0, 2219685438, 95129375951, 400000000000000000, address(this), "TEST"); // same owner for all markets (in test)
    }

    function test_marketHost18decimals_SetNewInterestModel_Failure() public {
        uint256 crtBorrowRateMaxMantissa = mTokenStorage(address(market18Decimals)).borrowRateMaxMantissa();
        console2.log("Current borrowRateMaxMantissa: ", crtBorrowRateMaxMantissa);

        assertEq(crtBorrowRateMaxMantissa, 5000000000000); //5e12

        vm.startPrank(ownerOnChain);
        vm.expectRevert(mTokenStorage.mt_BorrowRateTooHigh.selector);
        mTokenConfiguration(address(market18Decimals)).setInterestRateModel(address(newInterestModel));
        vm.stopPrank();

        //         │   │   ├─ [9978] 0x5372910e816879803577fA98D78c3C0D7764D415::getBorrowRate(262212727 [2.622e8], 359322111 [3.593e8], 621524837 [6.215e8]) [staticcall]
        // │   │   │   └─ ← [Return] 3417829867903211 [3.417e15]
        // │   │   └─ ← [Revert] mt_BorrowRateTooHigh()
        // │   └─ ← [Revert] mt_BorrowRateTooHigh()

        //assertEq(mTokenConfiguration(address(market18Decimals)).interestRateModel(), address(newInterestModel), "interest set issue");
    }

    function test_marketHost18decimals_SetNewInterestModelX() public {
        uint256 crtBorrowRate = mToken(address(market18Decimals)).borrowRatePerBlock();

        vm.startPrank(ownerOnChain);
        mTokenConfiguration(address(market18Decimals)).setBorrowRateMaxMantissa(1e18);
        mTokenConfiguration(address(market18Decimals)).setInterestRateModel(address(newInterestModel));

        // whitelist
        address operatorAddr = address(market18Decimals.operator());
        Operator(operatorAddr).setWhitelistedUser(address(this), true);
        vm.stopPrank();

        
        // allow firewall
        address firewall = 0x4E7bbAA670A5E2CD9a170Eb4E1468517Ad2A1448;
        bytes memory callData = abi.encodeWithSignature(
            "validateForbiddenContextInteraction(address,address)",
            0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38, 
            0xa31963C753f277f7d82d98F56b2C374256925eB7
        );
        vm.mockCall(firewall, callData, abi.encode(true));

        uint256 borrowRateBeforeMint = mToken(address(market18Decimals)).borrowRatePerBlock();

        // perform a deposit
        uint256 supplyAmount = 1e18;
        deal(address(asset18Decimals), address(this), supplyAmount);
        asset18Decimals.approve(address(market18Decimals), supplyAmount);
        market18Decimals.mint(supplyAmount, address(this), 0);

        uint256 balanceOfMarket18Decimals = IERC20(address(market18Decimals)).balanceOf(address(this));
        assertGt(balanceOfMarket18Decimals, 0, "mint didn't work");

        uint256 borrowRateAfterMint = mToken(address(market18Decimals)).borrowRatePerBlock();

        // test interest accrual
        mTokenStorage(address(market18Decimals)).accrueInterest();

        uint256 borrowRateAfterFirstAccrue = mToken(address(market18Decimals)).borrowRatePerBlock();

        vm.warp(block.timestamp + 0.1 days);

        // borrow
        uint256 borrowAmount = 1e17;
        market18Decimals.borrow(borrowAmount);

        uint256 borrowRateAfterBorrow = mToken(address(market18Decimals)).borrowRatePerBlock();

        borrowAmount = 4e17;
        market18Decimals.borrow(borrowAmount);
        uint256 borrowRateAfterSecondBorrow = mToken(address(market18Decimals)).borrowRatePerBlock();

        console2.log("Stats for borrow rate: ");
        console2.log(" - Current (before fix)  : ", crtBorrowRate);
        console2.log(" - After fix - 0 actions : ", borrowRateBeforeMint);
        console2.log(" - After mint            : ", borrowRateAfterMint);
        console2.log(" - After mint + accrue   : ", borrowRateAfterFirstAccrue);
        console2.log(" - After borrow          : ", borrowRateAfterBorrow);
        console2.log(" - After borrow          : ", borrowRateAfterSecondBorrow);

    }
}
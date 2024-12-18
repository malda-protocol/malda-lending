// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";
import {InvestmentContract} from "../../../src/investmentContract/investmentContract.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";

contract InvestmentContractTest is Test {
    InvestmentContract public investmentContract;
    ERC20Mock public usdc;

    address owner = makeAddr("owner");
    address investor = makeAddr("investor");
    uint256 constant MINIMUM_INVESTMENT = 10 * 1e6; // 10 USDC

    error OwnableUnauthorizedAccount(address account);
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    function setUp() public {
        usdc = new ERC20Mock("USDC", "USDC", 6);
        investmentContract = new InvestmentContract(address(usdc), owner);

        // Mint USDC to investor
        usdc.mint(investor, 1000 * 1e6);
    }

    function test_GivenInvestmentRoundIsClosed() external {
        vm.startPrank(owner);
        investmentContract.closeInvestmentRound();
        vm.stopPrank();

        vm.startPrank(investor);
        usdc.approve(address(investmentContract), MINIMUM_INVESTMENT);

        vm.expectRevert(InvestmentContract.InvestmentContract_InvestmentRoundClosed.selector);
        investmentContract.invest(MINIMUM_INVESTMENT);
        vm.stopPrank();
    }

    function test_GivenAmountIsBelowMinimum() external {
        vm.startPrank(investor);
        usdc.approve(address(investmentContract), MINIMUM_INVESTMENT - 1);

        vm.expectRevert(InvestmentContract.InvestmentContract_MinimumInvestmentNotMet.selector);
        investmentContract.invest(MINIMUM_INVESTMENT - 1);
        vm.stopPrank();
    }

    function test_GivenInsufficientAllowance() external {
        vm.startPrank(investor);
        // Not approving any USDC

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientAllowance.selector,
                address(investmentContract),
                usdc.allowance(investor, address(investmentContract)),
                MINIMUM_INVESTMENT
            )
        );
        investmentContract.invest(MINIMUM_INVESTMENT);
        vm.stopPrank();
    }

    modifier givenValidInvestmentParameters() {
        vm.startPrank(investor);
        usdc.approve(address(investmentContract), MINIMUM_INVESTMENT);
        _;
    }

    function test_WhenInvestIsCalled() external givenValidInvestmentParameters {
        uint256 investorBalanceBefore = usdc.balanceOf(investor);
        uint256 contractBalanceBefore = usdc.balanceOf(address(investmentContract));

        uint256 tokenId = investmentContract.nextTokenId();

        // Check event was emitted
        vm.expectEmit(true, true, false, true);
        emit InvestmentContract.InvestmentMade(investor, tokenId, MINIMUM_INVESTMENT);

        investmentContract.invest(MINIMUM_INVESTMENT);

        // Check investor's USDC balance decreased
        assertEq(usdc.balanceOf(investor), investorBalanceBefore - MINIMUM_INVESTMENT);

        // Check contract's USDC balance increased
        assertEq(usdc.balanceOf(address(investmentContract)), contractBalanceBefore + MINIMUM_INVESTMENT);

        // Check NFT was minted to investor
        assertEq(investmentContract.ownerOf(tokenId), investor);

        // Check investment amount was recorded
        assertEq(investmentContract.investments(tokenId), MINIMUM_INVESTMENT);

        vm.stopPrank();
    }

    modifier whenWithdrawIsCalled() {
        // First make an investment to have funds in the contract
        vm.startPrank(investor);
        usdc.approve(address(investmentContract), MINIMUM_INVESTMENT);
        investmentContract.invest(MINIMUM_INVESTMENT);
        vm.stopPrank();
        _;
    }

    function test_GivenWithdrawCallerIsNotOwner() external givenValidInvestmentParameters whenWithdrawIsCalled {
        vm.startPrank(investor);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, investor));
        investmentContract.withdraw(MINIMUM_INVESTMENT);
        vm.stopPrank();
    }

    function test_GivenContractHasInsufficientBalance() external givenValidInvestmentParameters whenWithdrawIsCalled {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientBalance.selector,
                address(investmentContract),
                usdc.balanceOf(address(investmentContract)),
                MINIMUM_INVESTMENT + 1
            )
        );
        investmentContract.withdraw(MINIMUM_INVESTMENT + 1);
        vm.stopPrank();
    }

    function test_GivenValidWithdrawalParameters() external givenValidInvestmentParameters whenWithdrawIsCalled {
        uint256 ownerBalanceBefore = usdc.balanceOf(owner);
        uint256 contractBalanceBefore = usdc.balanceOf(address(investmentContract));

        vm.startPrank(owner);
        investmentContract.withdraw(MINIMUM_INVESTMENT);

        // Check owner's USDC balance increased
        assertEq(usdc.balanceOf(owner), ownerBalanceBefore + MINIMUM_INVESTMENT);

        // Check contract's USDC balance decreased
        assertEq(usdc.balanceOf(address(investmentContract)), contractBalanceBefore - MINIMUM_INVESTMENT);

        vm.stopPrank();
    }

    modifier whenCloseInvestmentRoundIsCalled() {
        _;
    }

    function test_GivenCloseRoundCallerIsNotOwner()
        external
        givenValidInvestmentParameters
        whenCloseInvestmentRoundIsCalled
    {
        vm.startPrank(investor);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, investor));
        investmentContract.closeInvestmentRound();
        vm.stopPrank();
    }

    function test_GivenCallerIsOwner() external givenValidInvestmentParameters whenCloseInvestmentRoundIsCalled {
        vm.startPrank(owner);
        investmentContract.closeInvestmentRound();
        assertTrue(investmentContract.investmentRoundClosed());
        vm.stopPrank();
    }
}

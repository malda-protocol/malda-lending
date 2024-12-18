// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";
import {GovernanceRound} from "../../../src/governanceRound/governanceRound.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract GovernanceRoundTest is Test {
    using Strings for uint256;

    GovernanceRound public governanceRound;
    ERC20Mock public usdc;

    address owner = makeAddr("owner");
    address depositor = makeAddr("depositor");
    address operator = makeAddr("operator");
    uint256 constant MINIMUM_DEPOSIT = 10 * 1e6; // 10 USDC

    error OwnableUnauthorizedAccount(address account);
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC721NonexistentToken(uint256 tokenId);
    error GovernanceRound_CallerIsNotOperator();

    function setUp() public {
        usdc = new ERC20Mock("USDC", "USDC", 6);
        governanceRound = new GovernanceRound(address(usdc), owner, operator);

        // Mint USDC to depositor
        usdc.mint(depositor, 1000 * 1e6);
    }

    function test_GivenRoundIsClosed() external {
        vm.startPrank(operator);
        governanceRound.closeRound();
        vm.stopPrank();

        vm.startPrank(depositor);
        usdc.approve(address(governanceRound), MINIMUM_DEPOSIT);

        vm.expectRevert(GovernanceRound.GovernanceRound_RoundClosed.selector);
        governanceRound.deposit(MINIMUM_DEPOSIT);
        vm.stopPrank();
    }

    function test_GivenAmountIsBelowMinimum() external {
        vm.startPrank(depositor);
        usdc.approve(address(governanceRound), MINIMUM_DEPOSIT - 1);

        vm.expectRevert(GovernanceRound.GovernanceRound_MinimumDepositNotMet.selector);
        governanceRound.deposit(MINIMUM_DEPOSIT - 1);
        vm.stopPrank();
    }

    function test_GivenInsufficientAllowance() external {
        vm.startPrank(depositor);
        // Not approving any USDC

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientAllowance.selector,
                address(governanceRound),
                usdc.allowance(depositor, address(governanceRound)),
                MINIMUM_DEPOSIT
            )
        );
        governanceRound.deposit(MINIMUM_DEPOSIT);
        vm.stopPrank();
    }

    modifier givenValidDepositParameters() {
        vm.startPrank(depositor);
        usdc.approve(address(governanceRound), MINIMUM_DEPOSIT);
        _;
    }

    function test_WhenDepositIsCalled() external givenValidDepositParameters {
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        uint256 contractBalanceBefore = usdc.balanceOf(address(governanceRound));

        uint256 tokenId = governanceRound.nextTokenId();

        // Check event was emitted
        vm.expectEmit(true, true, false, true);
        emit GovernanceRound.DepositMade(depositor, tokenId, MINIMUM_DEPOSIT);

        governanceRound.deposit(MINIMUM_DEPOSIT);

        // Check investor's USDC balance decreased
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore - MINIMUM_DEPOSIT);

        // Check contract's USDC balance increased
        assertEq(usdc.balanceOf(address(governanceRound)), contractBalanceBefore + MINIMUM_DEPOSIT);

        // Check NFT was minted to investor
        assertEq(governanceRound.ownerOf(tokenId), depositor);

        // Check investment amount was recorded
        assertEq(governanceRound.deposits(tokenId), MINIMUM_DEPOSIT);

        vm.stopPrank();
    }

    modifier whenWithdrawIsCalled() {
        // First make an investment to have funds in the contract
        vm.startPrank(depositor);
        usdc.approve(address(governanceRound), MINIMUM_DEPOSIT);
        governanceRound.deposit(MINIMUM_DEPOSIT);
        vm.stopPrank();
        _;
    }

    function test_GivenWithdrawCallerIsNotOwner() external givenValidDepositParameters whenWithdrawIsCalled {
        vm.startPrank(depositor);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, depositor));
        governanceRound.withdraw(MINIMUM_DEPOSIT);
        vm.stopPrank();
    }

    function test_GivenContractHasInsufficientBalance() external givenValidDepositParameters whenWithdrawIsCalled {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientBalance.selector,
                address(governanceRound),
                usdc.balanceOf(address(governanceRound)),
                MINIMUM_DEPOSIT + 1
            )
        );
        governanceRound.withdraw(MINIMUM_DEPOSIT + 1);
        vm.stopPrank();
    }

    function test_GivenValidWithdrawalParameters() external givenValidDepositParameters whenWithdrawIsCalled {
        uint256 ownerBalanceBefore = usdc.balanceOf(owner);
        uint256 contractBalanceBefore = usdc.balanceOf(address(governanceRound));

        vm.startPrank(owner);
        governanceRound.withdraw(MINIMUM_DEPOSIT);

        // Check owner's USDC balance increased
        assertEq(usdc.balanceOf(owner), ownerBalanceBefore + MINIMUM_DEPOSIT);

        // Check contract's USDC balance decreased
        assertEq(usdc.balanceOf(address(governanceRound)), contractBalanceBefore - MINIMUM_DEPOSIT);

        vm.stopPrank();
    }

    modifier whenCloseRoundIsCalled() {
        _;
    }

    function test_GivenCloseRoundCallerIsNotOperator() external givenValidDepositParameters whenCloseRoundIsCalled {
        vm.startPrank(depositor);
        vm.expectRevert(abi.encodeWithSelector(GovernanceRound_CallerIsNotOperator.selector));
        governanceRound.closeRound();
        vm.stopPrank();
    }

    function test_GivenCallerIsOperator() external givenValidDepositParameters whenCloseRoundIsCalled {
        vm.startPrank(operator);
        governanceRound.closeRound();
        assertTrue(governanceRound.roundClosed());
        vm.stopPrank();
    }

    modifier whenTokenURIIsCalled() {
        _;
    }

    function test_GivenNonexistentTokenId() external whenTokenURIIsCalled {
        uint256 nonexistentTokenId = 999;

        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, nonexistentTokenId));
        governanceRound.tokenURI(nonexistentTokenId);
    }

    function test_GivenValidTokenId() external givenValidDepositParameters whenTokenURIIsCalled {
        // Make a deposit to mint a token
        uint256 depositAmount = MINIMUM_DEPOSIT * 2; // Using 20 USDC for clearer test
        usdc.approve(address(governanceRound), depositAmount);
        governanceRound.deposit(depositAmount);
        uint256 tokenId = governanceRound.nextTokenId() - 1;

        string memory expectedUri = string.concat("deposit_amount: ", depositAmount.toString());
        string memory actualUri = governanceRound.tokenURI(tokenId);

        assertEq(actualUri, expectedUri);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseUnitTest} from "test/v2/utils/BaseUnitTest.t.sol";

import {Risc0VerifierMock} from "test/mocks/Risc0VerifierMock.sol";
import {LendingProtocolMock} from "test/mocks/LendingProtocolMock.sol";

contract LendingProtocolMock_test is BaseUnitTest {
    LendingProtocolMock public protocol;
    Risc0VerifierMock public verifierMock;

    struct Commitment {
        uint256 id;
        bytes32 digest;
        bytes32 configID;
    }

    function setUp() public override {
        super.setUp();

        verifierMock = new Risc0VerifierMock();
        vm.label(address(verifierMock), "verifierMock");

        protocol = new LendingProtocolMock(address(weth), address(verifierMock), address(this));
        vm.label(address(protocol), "LendingProtocolMock");
    }

    function _createJournal(uint256 amount, address user) internal pure returns (bytes memory) {
        uint256 encodedID = uint256(0) << 240 | uint256(1); //version and value
        Commitment memory data = Commitment(encodedID, "", "0x123");
        return abi.encode(data, amount, user);
    }

    modifier whenSetVerifierIsCalled() {
        // does nothing; for readability only
        _;
    }

    ////////////////////////////////////////////////////////////
    //               GivenTheCallerIsNotTheOwner                //
    ////////////////////////////////////////////////////////////

    function test_unitGivenTheCallerIsNotTheOwner_success() external whenSetVerifierIsCalled {
        _resetContext(users.alice);
        vm.expectRevert();
        protocol.setVerifier(address(this));
    }

    ////////////////////////////////////////////////////////////
    //                 GivenTheCallerIsTheOwner                 //
    ////////////////////////////////////////////////////////////

    function test_unitGivenTheCallerIsTheOwner_success() external whenSetVerifierIsCalled {
        protocol.setVerifier(address(this));
        assertEq(address(protocol.verifier()), address(this));
    }

    modifier whenSetBorrowImageIdIsCalled() {
        // does nothing; for readability only
        _;
    }

    ////////////////////////////////////////////////////////////
    //                 GivenTheCallerIsNotOwner                 //
    ////////////////////////////////////////////////////////////

    function test_unitGivenTheCallerIsNotOwner_success() external whenSetBorrowImageIdIsCalled {
        _resetContext(users.alice);
        vm.expectRevert();
        protocol.setBorrowImageId(bytes32("0x1"));
    }

    ////////////////////////////////////////////////////////////
    //                  GivenTheCallerIsOwnerX                  //
    ////////////////////////////////////////////////////////////

    function test_unitGivenTheCallerIsOwnerX_success() external whenSetBorrowImageIdIsCalled {
        protocol.setBorrowImageId(bytes32("0x1"));
        assertEq(protocol.borrowImageId(), bytes32("0x1"));
    }

    modifier whenDepositIsCalled() {
        // does nothing; for readability only
        _;
    }

    ////////////////////////////////////////////////////////////
    //                   GivenTheAmountIsZero                   //
    ////////////////////////////////////////////////////////////

    function test_unitGivenTheAmountIsZero_success() external whenDepositIsCalled {
        uint256 balanceBefore = protocol.balanceOf(address(this));
        protocol.deposit(0, address(this));
        uint256 balanceAfter = protocol.balanceOf(address(this));

        assertEq(balanceAfter, balanceBefore);
    }

    ////////////////////////////////////////////////////////////
    //              WhenTheAmountIsGreaterThanZero              //
    ////////////////////////////////////////////////////////////

    function test_unitWhenTheAmountIsGreaterThanZero_success(uint256 amount) external whenDepositIsCalled {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(protocol), amount);

        uint256 underlyingBalanceBefore = weth.balanceOf(address(this));
        uint256 balanceBefore = protocol.balanceOf(address(this));
        protocol.deposit(amount, address(this));
        uint256 underlyingBalanceAfter = weth.balanceOf(address(this));
        uint256 balanceAfter = protocol.balanceOf(address(this));

        // it should increase the recipient’s balance
        assertEq(balanceAfter, balanceBefore + amount);

        // it should transfer tokens to the contract
        assertEq(underlyingBalanceAfter + amount, underlyingBalanceBefore);
    }

    modifier whenBorrowIsCalled() {
        // does nothing; for readability only
        _;
    }

    ////////////////////////////////////////////////////////////
    //               GivenTheJournalDataIsInvalid               //
    ////////////////////////////////////////////////////////////

    function test_unitGivenTheJournalDataIsInvalid_success(uint256 amount) external whenBorrowIsCalled {
        amount = bound(amount, SMALL, LARGE);

        // it should revert with LendingProtocolMock_JournalNotValid
        vm.expectRevert(LendingProtocolMock.LendingProtocolMock_JournalNotValid.selector);
        protocol.borrow(amount, "", "0x123");
    }

    ////////////////////////////////////////////////////////////
    //             GivenTheLiquidityIsInsufficientX             //
    ////////////////////////////////////////////////////////////

    function test_unitGivenTheLiquidityIsInsufficientX_success(uint256 amount) external whenBorrowIsCalled {
        amount = bound(amount, SMALL, LARGE);

        bytes memory journalData = _createJournal(amount / 2, address(this));

        vm.expectRevert(LendingProtocolMock.LendingProtocolMock_InsufficientLiquidity.selector);
        protocol.borrow(amount, journalData, "0x123");
        // it should revert with LendingProtocolMock_InsufficientLiquidity
    }

    modifier whenLiquidityIsSufficient() {
        // does nothing; for readability only
        _;
    }

    ////////////////////////////////////////////////////////////
    //          WhenThereAreEnoughTokensInTheContract           //
    ////////////////////////////////////////////////////////////

    function test_unitWhenThereAreEnoughTokensInTheContract_success(uint256 amount)
        external
        whenBorrowIsCalled
        whenLiquidityIsSufficient
    {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(protocol), amount);

        protocol.deposit(amount, address(this));

        uint256 underlyingBalanceBefore = weth.balanceOf(address(this));
        uint256 balanceBorrowBefore = protocol.borrowBalanceOf(address(this));

        bytes memory journalData = _createJournal(amount, address(this));
        protocol.borrow(amount, journalData, "0x123");

        uint256 underlyingBalanceAfter = weth.balanceOf(address(this));
        uint256 balanceBorrowAfter = protocol.borrowBalanceOf(address(this));

        // it should transfer tokens to the user
        assertEq(underlyingBalanceAfter, underlyingBalanceBefore + amount);

        // it should increase the user's borrow balance
        assertEq(balanceBorrowAfter, balanceBorrowBefore + amount);
    }

    ////////////////////////////////////////////////////////////
    //        GivenThereAreNotEnoughTokensInTheContract         //
    ////////////////////////////////////////////////////////////

    function test_unitGivenThereAreNotEnoughTokensInTheContract_success(uint256 amount)
        external
        whenBorrowIsCalled
        whenLiquidityIsSufficient
    {
        amount = bound(amount, SMALL, LARGE);

        bytes memory journalData = _createJournal(amount, address(this));

        vm.expectRevert(LendingProtocolMock.LendingProtocolMock_InsufficientBalance.selector);
        protocol.borrow(amount, journalData, "0x123");

        // it should revert with LendingProtocolMock_InsufficientBalance
    }

    modifier whenRepayIsCalled() {
        // does nothing; for readability only
        _;
    }

    ////////////////////////////////////////////////////////////
    //           GivenTheBorrowBalanceIsInsufficient            //
    ////////////////////////////////////////////////////////////

    function test_unitGivenTheBorrowBalanceIsInsufficient_success(uint256 amount) external whenRepayIsCalled {
        amount = bound(amount, SMALL, LARGE);

        vm.expectRevert(LendingProtocolMock.LendingProtocolMock_InsufficientBalance.selector);
        protocol.repay(amount);
    }

    ////////////////////////////////////////////////////////////
    //             WhenTheBorrowBalanceIsSufficient             //
    ////////////////////////////////////////////////////////////

    function test_unitWhenTheBorrowBalanceIsSufficient_success(uint256 amount) external whenRepayIsCalled {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(protocol), amount);
        protocol.deposit(amount, address(this));

        bytes memory journalData = _createJournal(amount, address(this));
        protocol.borrow(amount, journalData, "0x123");

        uint256 underlyingBalanceBefore = weth.balanceOf(address(this));
        uint256 balanceBorrowBefore = protocol.borrowBalanceOf(address(this));
        weth.approve(address(protocol), amount);
        protocol.repay(amount);
        uint256 balanceBorrowAfter = protocol.borrowBalanceOf(address(this));
        uint256 underlyingBalanceAfter = weth.balanceOf(address(this));

        // it should reduce the borrow balance
        assertEq(balanceBorrowBefore - amount, balanceBorrowAfter);

        // it should transfer tokens from the user to the contract
        assertEq(underlyingBalanceAfter + amount, underlyingBalanceBefore);
    }

    modifier whenWithdrawIsCalled() {
        // does nothing; for readability only
        _;
    }

    ////////////////////////////////////////////////////////////
    //            GivenTheUsersBalanceIsInsufficient            //
    ////////////////////////////////////////////////////////////

    function test_unitGivenTheUsersBalanceIsInsufficient_success(uint256 amount) external whenWithdrawIsCalled {
        amount = bound(amount, SMALL, LARGE);

        bytes memory journalData = _createJournal(amount, address(this));
        vm.expectRevert(LendingProtocolMock.LendingProtocolMock_InsufficientBalance.selector);
        protocol.withdraw(amount, journalData, "0x123");
    }

    ////////////////////////////////////////////////////////////
    //             WhenTheUsersBalanceIsSufficient              //
    ////////////////////////////////////////////////////////////

    function test_unitWhenTheUsersBalanceIsSufficient_success(uint256 amount) external whenWithdrawIsCalled {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(protocol), amount);
        protocol.deposit(amount, address(this));

        uint256 underlyingBalanceBefore = weth.balanceOf(address(this));
        uint256 balanceBefore = protocol.balanceOf(address(this));

        bytes memory journalData = _createJournal(amount, address(this));
        protocol.withdraw(amount, journalData, "0x123");

        uint256 underlyingBalanceAfter = weth.balanceOf(address(this));
        uint256 balanceAfter = protocol.balanceOf(address(this));

        // it should reduce the user's balance
        assertEq(balanceAfter + amount, balanceBefore);

        // it should transfer tokens to the user
        assertEq(underlyingBalanceBefore + amount, underlyingBalanceAfter);
    }
}

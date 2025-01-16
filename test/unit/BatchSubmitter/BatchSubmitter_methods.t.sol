// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {BatchSubmitter_Unit_Shared} from "../shared/BatchSubmitter_Unit_Shared.t.sol";
import {BatchSubmitter} from "src/mToken/BatchSubmitter.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";

contract BatchSubmitter_methods is BatchSubmitter_Unit_Shared {
    bytes[] internal journals;
    uint256[] internal amounts;
    address[] internal mTokens;

    function setUp() public virtual override {
        super.setUp();
        
        address[] memory senders = new address[](2);
        senders[0] = address(this);
        senders[1] = address(this);

        address[] memory markets = new address[](2);
        markets[0] = address(mWethExtension);
        markets[1] = address(mUsdcExtension);

        amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;

        mTokens = markets;

        bytes memory encodedJournals = _createBatchJournals(
            senders, 
            markets, 
            amounts,
            TEST_SOURCE_CHAIN_ID,
            uint32(block.chainid)
        );
        journals = abi.decode(encodedJournals, (bytes[]));
    }

    modifier givenSenderDoesNotHaveProofForwarderRole() {
        _;
    }

    function test_RevertWhen_CallerIsNotProofForwarder() external givenSenderDoesNotHaveProofForwarderRole {
        bytes memory encodedJournals = abi.encode(journals);
        vm.expectRevert(BatchSubmitter.BatchSubmitter_CallerNotAllowed.selector);
        batchSubmitter.batchOutHere(encodedJournals, "", mTokens, amounts, 0, journals.length);
    }

    modifier givenSenderHasProofForwarderRole() {
        roles.allowFor(address(this), roles.PROOF_FORWARDER(), true);
        _;
    }

    modifier givenJournalDataIsEmpty() {
        _;
    }

    function test_RevertWhen_JournalDataIsEmpty() 
        external 
        givenSenderHasProofForwarderRole 
        givenJournalDataIsEmpty 
    {
        vm.expectRevert(BatchSubmitter.BatchSubmitter_JournalNotValid.selector);
        batchSubmitter.batchOutHere("", "", mTokens, amounts, 0, 0);
    }

    modifier givenJournalDataIsValid() {
        _;
    }

    function test_WhenOutHereSucceeds(uint256 amount) 
        external 
        givenSenderHasProofForwarderRole 
        givenJournalDataIsValid
        inRange(amount, SMALL, LARGE)
    {
        address[] memory senders = new address[](1);
        senders[0] = address(this);

        address[] memory testMTokens = new address[](1);
        testMTokens[0] = address(mWethExtension);
        
        uint256[] memory testAmounts = new uint256[](1);
        testAmounts[0] = amount;

        bytes memory encodedJournals = _createBatchJournals(
            senders, 
            testMTokens, 
            testAmounts,
            TEST_SOURCE_CHAIN_ID,
            uint32(block.chainid)
        );
        
        // Fund the gateway
        _getTokens(weth, address(mWethExtension), amount);

        // Record balances before
        uint256 balanceBefore = weth.balanceOf(address(this));
        uint256 gatewayBalanceBefore = weth.balanceOf(address(mWethExtension));
        
        batchSubmitter.batchOutHere(encodedJournals, "0x123", testMTokens, testAmounts, 0, 1);

        // Check balances after
        uint256 balanceAfter = weth.balanceOf(address(this));
        uint256 gatewayBalanceAfter = weth.balanceOf(address(mWethExtension));

        // Verify balances changed correctly
        assertEq(balanceAfter - balanceBefore, amount);
        assertEq(gatewayBalanceBefore - gatewayBalanceAfter, amount);
    }

    function test_WhenOutHereFails() 
        external 
        givenSenderHasProofForwarderRole 
        givenJournalDataIsValid 
    {
        address[] memory senders = new address[](1);
        senders[0] = address(this);

        address[] memory markets = new address[](1);
        markets[0] = address(0); // Invalid market address

        uint256[] memory testAmounts = new uint256[](1);
        testAmounts[0] = 1 ether;

        bytes memory encodedJournals = _createBatchJournals(
            senders, 
            markets, 
            testAmounts,
            TEST_SOURCE_CHAIN_ID,
            uint32(block.chainid)
        );
        bytes[] memory decodedJournals = abi.decode(encodedJournals, (bytes[]));
        
        address[] memory testMTokens = new address[](1);
        testMTokens[0] = address(mWethExtension);

        vm.expectEmit(true, true, true, true);
        emit BatchSubmitter.BatchOutHereFailed(
            decodedJournals[0], 
            abi.encodePacked(ImTokenGateway.mTokenGateway_AddressNotValid.selector)
        );
        
        batchSubmitter.batchOutHere(encodedJournals, "", testMTokens, testAmounts, 0, 1);
    }
} 
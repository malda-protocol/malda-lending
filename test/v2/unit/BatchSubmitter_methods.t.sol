// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {BatchSubmitter_Unit_Shared} from "test/unit/shared/BatchSubmitter_Unit_Shared.t.sol";
import {BatchSubmitter} from "src/mToken/BatchSubmitter.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";

contract MockBatchHost {
    function repayExternal(bytes calldata, bytes calldata, uint256[] calldata, address) external {}

    function liquidateExternal(
        bytes calldata,
        bytes calldata,
        address[] calldata,
        uint256[] calldata,
        address[] calldata,
        address
    ) external {}
}

contract BatchSubmitter_methods is BatchSubmitter_Unit_Shared {
    bytes[] internal journals;
    uint256[] internal amounts;
    address[] internal mTokens;
    bytes4[] internal selectors;
    address[] internal receivers;
    bytes32[] internal initHashes;

    // Define selectors from interfaces
    bytes4 internal constant OUT_HERE_SELECTOR = ImTokenGateway.outHere.selector;
    bytes4 internal constant MINT_SELECTOR = ImErc20Host.mintExternal.selector;
    bytes4 internal constant REPAY_SELECTOR = ImErc20Host.repayExternal.selector;
    bytes4 internal constant LIQUIDATE_SELECTOR = ImErc20Host.liquidateExternal.selector;

    modifier whenMarketIsListed(address mToken) {
        operator.supportMarket(mToken);
        _;
    }

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

        selectors = new bytes4[](2);
        selectors[0] = OUT_HERE_SELECTOR;
        selectors[1] = OUT_HERE_SELECTOR;

        bytes memory encodedJournals = _createBatchJournals(
            senders,
            markets,
            amounts,
            TEST_SOURCE_CHAIN_ID,
            uint32(block.chainid),
            true // Set L1inclusion to true for tests
        );
        journals = abi.decode(encodedJournals, (bytes[]));

        // Initialize new state variables
        receivers = new address[](2);
        receivers[0] = address(this);
        receivers[1] = address(this);

        initHashes = new bytes32[](2);
        initHashes[0] = keccak256(journals[0]);
        initHashes[1] = keccak256(journals[1]);
    }

    modifier givenSenderDoesNotHaveProofForwarderRole() {
        _;
    }

    function test_RevertWhen_CallerIsNotProofForwarder() external givenSenderDoesNotHaveProofForwarderRole {
        bytes memory encodedJournals = abi.encode(journals);
        vm.expectRevert(BatchSubmitter.BatchSubmitter_CallerNotAllowed.selector);
        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "",
                mTokens,
                amounts,
                amounts,
                selectors,
                initHashes,
                0,
                new address[](0),
                new address[](0)
            )
        );
    }

    modifier givenSenderHasProofForwarderRole() {
        roles.allowFor(address(this), roles.PROOF_FORWARDER(), true);
        _;
    }

    modifier givenJournalDataIsEmpty() {
        _;
    }

    function test_RevertWhen_JournalDataIsEmpty() external givenSenderHasProofForwarderRole givenJournalDataIsEmpty {
        vm.expectRevert(BatchSubmitter.BatchSubmitter_JournalNotValid.selector);

        receivers = new address[](1);
        receivers[0] = address(this);

        initHashes = new bytes32[](1);
        initHashes[0] = bytes32(0);

        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                "",
                "",
                mTokens,
                amounts,
                amounts,
                selectors,
                initHashes,
                0,
                new address[](0),
                new address[](0)
            )
        );
    }

    function test_UpdateZkVerifier_RevertWhenZero() external {
        vm.expectRevert(BatchSubmitter.BatchSubmitter_AddressNotValid.selector);
        batchSubmitter.updateZkVerifier(address(0));
    }

    function test_UpdateZkVerifier_Updates() external {
        ZkVerifier newVerifier = new ZkVerifier(address(this), "0x456", address(verifierMock));

        vm.expectEmit(true, true, true, true);
        emit BatchSubmitter.ZkVerifierUpdated(address(zkVerifier), address(newVerifier));

        batchSubmitter.updateZkVerifier(address(newVerifier));
        assertEq(address(batchSubmitter.verifier()), address(newVerifier));
    }

    function test_RevertWhen_InvalidSelector() external givenSenderHasProofForwarderRole {
        bytes4[] memory invalidSelectors = new bytes4[](1);
        invalidSelectors[0] = bytes4(0x12345678); // Invalid selector

        // Reset storage arrays to length 1
        mTokens = new address[](1);
        mTokens[0] = address(mWethExtension);

        amounts = new uint256[](1);
        amounts[0] = 1 ether;

        receivers = new address[](1);
        receivers[0] = address(this);

        bytes memory encodedJournals =
            _createBatchJournals(new address[](1), mTokens, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        initHashes = new bytes32[](1);
        initHashes[0] = keccak256(journals[0]);

        vm.expectRevert(BatchSubmitter.BatchSubmitter_InvalidSelector.selector);
        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "",
                mTokens,
                amounts,
                amounts,
                invalidSelectors,
                initHashes,
                0,
                new address[](0),
                new address[](0)
            )
        );
    }

    modifier givenJournalDataIsValid() {
        _;
    }

    function test_WhenOutHereSucceeds(uint256 amount)
        external
        givenSenderHasProofForwarderRole
        givenJournalDataIsValid
    {
        amount = bound(amount, SMALL, LARGE);

        // Reset storage arrays to length 1
        mTokens = new address[](1);
        mTokens[0] = address(mWethExtension);

        amounts = new uint256[](1);
        amounts[0] = amount;

        selectors = new bytes4[](1);
        selectors[0] = OUT_HERE_SELECTOR;

        receivers = new address[](1);
        receivers[0] = address(this);

        bytes memory encodedJournals =
            _createBatchJournals(receivers, mTokens, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        initHashes = new bytes32[](1);
        initHashes[0] = keccak256(journals[0]);

        // Fund the gateway
        _getTokens(weth, address(mWethExtension), amount);

        // Record balances before
        uint256 balanceBefore = weth.balanceOf(address(this));
        uint256 gatewayBalanceBefore = weth.balanceOf(address(mWethExtension));

        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "0x123",
                mTokens,
                amounts,
                amounts,
                selectors,
                initHashes,
                0,
                new address[](0),
                new address[](0)
            )
        );

        // Check balances after
        uint256 balanceAfter = weth.balanceOf(address(this));
        uint256 gatewayBalanceAfter = weth.balanceOf(address(mWethExtension));

        // Verify balances changed correctly
        assertEq(balanceAfter - balanceBefore, amount);
        assertEq(gatewayBalanceBefore - gatewayBalanceAfter, amount);
    }

    function test_WhenOutHereFails() external givenSenderHasProofForwarderRole givenJournalDataIsValid {
        // Reset storage arrays to length 1
        mTokens = new address[](1);
        mTokens[0] = address(mWethExtension);

        amounts = new uint256[](1);
        amounts[0] = 1 ether;

        selectors = new bytes4[](1);
        selectors[0] = OUT_HERE_SELECTOR;

        receivers = new address[](1);
        receivers[0] = address(this);

        address[] memory senders = new address[](1);
        senders[0] = address(this);

        address[] memory markets = new address[](1);
        markets[0] = address(0); // Invalid market address

        bytes memory encodedJournals =
            _createBatchJournals(senders, markets, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        initHashes = new bytes32[](1);
        initHashes[0] = keccak256(journals[0]);

        vm.expectEmit(true, true, true, true);
        emit BatchSubmitter.BatchProcessFailed(
            initHashes[0],
            receivers[0],
            mTokens[0],
            amounts[0],
            amounts[0],
            selectors[0],
            abi.encodePacked(ImTokenGateway.mTokenGateway_AddressNotValid.selector)
        );

        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "",
                mTokens,
                amounts,
                amounts,
                selectors,
                initHashes,
                0,
                new address[](0),
                new address[](0)
            )
        );
    }

    function test_WhenMintSucceeds(uint256 amount) external givenSenderHasProofForwarderRole givenJournalDataIsValid {
        amount = bound(amount, SMALL, LARGE);

        // Reset storage arrays to length 1
        mTokens = new address[](1);
        mTokens[0] = address(mWethHost);

        amounts = new uint256[](1);
        amounts[0] = amount;

        selectors = new bytes4[](1);
        selectors[0] = MINT_SELECTOR;

        receivers = new address[](1);
        receivers[0] = address(this);

        address[] memory senders = new address[](1);
        senders[0] = address(this);

        bytes memory encodedJournals =
            _createBatchJournals(senders, mTokens, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        initHashes = new bytes32[](1);
        initHashes[0] = keccak256(journals[0]);

        // Record balances before
        uint256 balanceBefore = mWethHost.balanceOf(address(this));
        uint256 totalSupplyBefore = mWethHost.totalSupply();

        uint256[] memory minAmounts = new uint256[](1);
        minAmounts[0] = amount - 1000;

        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "0x123",
                mTokens,
                amounts,
                minAmounts,
                selectors,
                initHashes,
                0,
                new address[](0),
                new address[](0)
            )
        );

        // Check balances after
        uint256 balanceAfter = mWethHost.balanceOf(address(this));
        uint256 totalSupplyAfter = mWethHost.totalSupply();

        // Verify balances changed correctly
        assertGt(balanceAfter, balanceBefore);
        assertGt(totalSupplyAfter, totalSupplyBefore);
        assertEq(totalSupplyAfter - amount, totalSupplyBefore);
    }

    function test_WhenMintFails() external givenSenderHasProofForwarderRole givenJournalDataIsValid {
        // Reset storage arrays to length 1
        mTokens = new address[](1);
        mTokens[0] = address(mWethHost);

        amounts = new uint256[](1);
        amounts[0] = 1 ether;

        selectors = new bytes4[](1);
        selectors[0] = MINT_SELECTOR;

        receivers = new address[](1);
        receivers[0] = address(this);

        address[] memory senders = new address[](1);
        senders[0] = address(this);

        address[] memory markets = new address[](1);
        markets[0] = address(0); // Invalid market address

        bytes memory encodedJournals =
            _createBatchJournals(senders, markets, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        initHashes = new bytes32[](1);
        initHashes[0] = keccak256(journals[0]);

        vm.expectEmit(true, true, true, true);
        emit BatchSubmitter.BatchProcessFailed(
            initHashes[0],
            receivers[0],
            mTokens[0],
            amounts[0],
            amounts[0],
            selectors[0],
            abi.encodePacked(ImErc20Host.mErc20Host_AddressNotValid.selector)
        );

        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "",
                mTokens,
                amounts,
                amounts,
                selectors,
                initHashes,
                0,
                new address[](0),
                new address[](0)
            )
        );
    }

    function test_WhenRepayFails() external givenSenderHasProofForwarderRole givenJournalDataIsValid {
        // Reset storage arrays to length 1
        mTokens = new address[](1);
        mTokens[0] = address(mWethHost);

        amounts = new uint256[](1);
        amounts[0] = 1 ether;

        selectors = new bytes4[](1);
        selectors[0] = REPAY_SELECTOR;

        receivers = new address[](1);
        receivers[0] = address(this);

        address[] memory senders = new address[](1);
        senders[0] = address(this);

        address[] memory markets = new address[](1);
        markets[0] = address(0); // Invalid market address

        bytes memory encodedJournals =
            _createBatchJournals(senders, markets, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        initHashes = new bytes32[](1);
        initHashes[0] = keccak256(journals[0]);

        vm.expectEmit(true, true, true, true);
        emit BatchSubmitter.BatchProcessFailed(
            initHashes[0],
            receivers[0],
            mTokens[0],
            amounts[0],
            amounts[0],
            selectors[0],
            abi.encodePacked(ImErc20Host.mErc20Host_AddressNotValid.selector)
        );

        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "",
                mTokens,
                amounts,
                amounts,
                selectors,
                initHashes,
                0,
                new address[](0),
                new address[](0)
            )
        );
    }

    // ----------- LIQUIDATE TESTS -----------

    function test_WhenLiquidateSucceeds(uint256 amount)
        external
        givenSenderHasProofForwarderRole
        givenJournalDataIsValid
    {
        amount = bound(amount, SMALL, LARGE);

        // Reset storage arrays to length 1
        mTokens = new address[](1);
        mTokens[0] = address(mWethHost);

        amounts = new uint256[](1);
        amounts[0] = amount;

        selectors = new bytes4[](1);
        selectors[0] = LIQUIDATE_SELECTOR;

        receivers = new address[](1);
        receivers[0] = address(this);

        address[] memory userToLiquidate = new address[](1);
        userToLiquidate[0] = address(0x123); // User to liquidate

        address[] memory collateral = new address[](1);
        collateral[0] = address(mWethHost); // Collateral token

        address[] memory senders = new address[](1);
        senders[0] = address(this);

        bytes memory encodedJournals =
            _createBatchJournals(senders, mTokens, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        initHashes = new bytes32[](1);
        initHashes[0] = keccak256(journals[0]);

        // Expect the liquidateExternal call to be made with correct parameters
        vm.expectCall(
            address(mWethHost),
            abi.encodeWithSelector(
                ImErc20Host.liquidateExternal.selector,
                encodedJournals,
                "",
                userToLiquidate,
                amounts,
                collateral,
                receivers[0]
            )
        );

        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "0x123",
                mTokens,
                amounts,
                amounts,
                selectors,
                initHashes,
                0,
                userToLiquidate,
                collateral
            )
        );
    }

    function test_WhenLiquidateFails_ButMintSucceeds()
        external
        givenSenderHasProofForwarderRole
        givenJournalDataIsValid
    {
        // Reset storage arrays to length 1
        mTokens = new address[](1);
        mTokens[0] = address(mWethHost);

        amounts = new uint256[](1);
        amounts[0] = 1 ether;

        selectors = new bytes4[](1);
        selectors[0] = LIQUIDATE_SELECTOR;

        receivers = new address[](1);
        receivers[0] = address(this);

        address[] memory userToLiquidate = new address[](1);
        userToLiquidate[0] = address(0x123); // User to liquidate

        address[] memory collateral = new address[](1);
        collateral[0] = address(0); // Invalid collateral address

        address[] memory senders = new address[](1);
        senders[0] = address(this);

        bytes memory encodedJournals =
            _createBatchJournals(senders, mTokens, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        initHashes = new bytes32[](1);
        initHashes[0] = keccak256(journals[0]);

        // Expect liquidateExternal to be called first (and fail)
        vm.expectCall(
            address(mWethHost),
            abi.encodeWithSelector(
                ImErc20Host.liquidateExternal.selector,
                encodedJournals,
                "",
                userToLiquidate,
                amounts,
                collateral,
                receivers[0]
            )
        );

        // Expect mintExternal to be called as fallback (and succeed)

        vm.expectCall(
            address(mWethHost),
            abi.encodeWithSelector(
                ImErc20Host.mintExternal.selector, encodedJournals, "", amounts, new uint256[](1), receivers[0]
            )
        );

        // Expect success event with MINT_SELECTOR (not LIQUIDATE_SELECTOR)
        vm.expectEmit(true, true, true, true);
        emit BatchSubmitter.BatchProcessSuccess(
            initHashes[0], receivers[0], mTokens[0], amounts[0], amounts[0], MINT_SELECTOR
        );

        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "0x123",
                mTokens,
                amounts,
                amounts,
                selectors,
                initHashes,
                0,
                userToLiquidate,
                collateral
            )
        );
    }

    function test_WhenLiquidateFails_AndMintAlsoFails()
        external
        givenSenderHasProofForwarderRole
        givenJournalDataIsValid
    {
        // Reset storage arrays to length 1
        mTokens = new address[](1);
        mTokens[0] = address(mWethHost);

        amounts = new uint256[](1);
        amounts[0] = 1 ether;

        selectors = new bytes4[](1);
        selectors[0] = LIQUIDATE_SELECTOR;

        receivers = new address[](1);
        receivers[0] = address(this);

        address[] memory userToLiquidate = new address[](1);
        userToLiquidate[0] = address(0x123); // User to liquidate

        address[] memory collateral = new address[](1);
        collateral[0] = address(0); // Invalid collateral address

        address[] memory senders = new address[](1);
        senders[0] = address(this);

        address[] memory markets = new address[](1);
        markets[0] = address(0); // Invalid market address

        bytes memory encodedJournals =
            _createBatchJournals(senders, markets, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        initHashes = new bytes32[](1);
        initHashes[0] = keccak256(journals[0]);

        // Expect liquidateExternal to be called first (and fail)
        vm.expectCall(
            address(mWethHost),
            abi.encodeWithSelector(
                ImErc20Host.liquidateExternal.selector,
                encodedJournals,
                "",
                userToLiquidate,
                amounts,
                collateral,
                receivers[0]
            )
        );

        vm.expectCall(
            address(mWethHost),
            abi.encodeWithSelector(
                ImErc20Host.mintExternal.selector, encodedJournals, "", amounts, new uint256[](1), receivers[0]
            )
        );

        // Expect failure event with original LIQUIDATE_SELECTOR
        vm.expectEmit(true, true, true, true);
        emit BatchSubmitter.BatchProcessFailed(
            initHashes[0],
            receivers[0],
            mTokens[0],
            amounts[0],
            0,
            selectors[0],
            abi.encodePacked(ImErc20Host.mErc20Host_AddressNotValid.selector)
        );

        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "",
                mTokens,
                amounts,
                amounts,
                selectors,
                initHashes,
                0,
                userToLiquidate,
                collateral
            )
        );
    }

    function test_WhenLiquidateWithMultipleOperations()
        external
        givenSenderHasProofForwarderRole
        givenJournalDataIsValid
    {
        // Test multiple liquidate operations in a single batch
        mTokens = new address[](2);
        mTokens[0] = address(mWethHost);
        mTokens[1] = address(mUsdcHost);

        amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 1000 * 10 ** 6; // 1000 USDC

        selectors = new bytes4[](2);
        selectors[0] = LIQUIDATE_SELECTOR;
        selectors[1] = LIQUIDATE_SELECTOR;

        receivers = new address[](2);
        receivers[0] = address(this);
        receivers[1] = address(0x456);

        address[] memory userToLiquidate = new address[](2);
        userToLiquidate[0] = address(0x123);
        userToLiquidate[1] = address(0x789);

        address[] memory collateral = new address[](2);
        collateral[0] = address(mWethHost);
        collateral[1] = address(mUsdcHost);

        address[] memory senders = new address[](2);
        senders[0] = address(this);
        senders[1] = address(this);

        bytes memory encodedJournals =
            _createBatchJournals(senders, mTokens, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        initHashes = new bytes32[](2);
        initHashes[0] = keccak256(journals[0]);
        initHashes[1] = keccak256(journals[1]);

        // Expect the first liquidateExternal call to be made with correct parameters
        bytes[] memory singleJournal1 = new bytes[](1);
        singleJournal1[0] = journals[0];

        address[] memory singleUserToLiquidate1 = new address[](1);
        singleUserToLiquidate1[0] = userToLiquidate[0];

        uint256[] memory singleAmount1 = new uint256[](1);
        singleAmount1[0] = amounts[0];

        address[] memory singleCollateral1 = new address[](1);
        singleCollateral1[0] = collateral[0];

        vm.expectCall(
            address(mWethHost),
            abi.encodeWithSelector(
                ImErc20Host.liquidateExternal.selector,
                abi.encode(singleJournal1),
                "",
                singleUserToLiquidate1,
                singleAmount1,
                singleCollateral1,
                receivers[0]
            )
        );

        // Expect the second liquidateExternal call to be made with correct parameters
        bytes[] memory singleJournal2 = new bytes[](1);
        singleJournal2[0] = journals[1];

        address[] memory singleUserToLiquidate2 = new address[](1);
        singleUserToLiquidate2[0] = userToLiquidate[1];

        uint256[] memory singleAmount2 = new uint256[](1);
        singleAmount2[0] = amounts[1];

        address[] memory singleCollateral2 = new address[](1);
        singleCollateral2[0] = collateral[1];

        vm.expectCall(
            address(mUsdcHost),
            abi.encodeWithSelector(
                ImErc20Host.liquidateExternal.selector,
                abi.encode(singleJournal2),
                "",
                singleUserToLiquidate2,
                singleAmount2,
                singleCollateral2,
                receivers[1]
            )
        );

        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "0x123",
                mTokens,
                amounts,
                amounts,
                selectors,
                initHashes,
                0,
                userToLiquidate,
                collateral
            )
        );
    }

    function test_WhenRepaySucceeds() external givenSenderHasProofForwarderRole givenJournalDataIsValid {
        MockBatchHost mockHost = new MockBatchHost();

        mTokens = new address[](1);
        mTokens[0] = address(mockHost);

        amounts = new uint256[](1);
        amounts[0] = 1 ether;

        selectors = new bytes4[](1);
        selectors[0] = REPAY_SELECTOR;

        receivers = new address[](1);
        receivers[0] = address(this);

        address[] memory senders = new address[](1);
        senders[0] = address(this);

        bytes memory encodedJournals =
            _createBatchJournals(senders, mTokens, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        initHashes = new bytes32[](1);
        initHashes[0] = keccak256(journals[0]);

        vm.expectEmit(true, true, true, true);
        emit BatchSubmitter.BatchProcessSuccess(
            initHashes[0], receivers[0], mTokens[0], amounts[0], amounts[0], selectors[0]
        );

        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "0x123",
                mTokens,
                amounts,
                amounts,
                selectors,
                initHashes,
                0,
                new address[](0),
                new address[](0)
            )
        );
    }

    function test_WhenLiquidateSucceedsWithMock() external givenSenderHasProofForwarderRole givenJournalDataIsValid {
        MockBatchHost mockHost = new MockBatchHost();

        mTokens = new address[](1);
        mTokens[0] = address(mockHost);

        amounts = new uint256[](1);
        amounts[0] = 1 ether;

        selectors = new bytes4[](1);
        selectors[0] = LIQUIDATE_SELECTOR;

        receivers = new address[](1);
        receivers[0] = address(this);

        address[] memory userToLiquidate = new address[](1);
        userToLiquidate[0] = address(0x123);

        address[] memory collateral = new address[](1);
        collateral[0] = address(0x456);

        address[] memory senders = new address[](1);
        senders[0] = address(this);

        bytes memory encodedJournals =
            _createBatchJournals(senders, mTokens, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        initHashes = new bytes32[](1);
        initHashes[0] = keccak256(journals[0]);

        vm.expectEmit(true, true, true, true);
        emit BatchSubmitter.BatchProcessSuccess(
            initHashes[0], receivers[0], mTokens[0], amounts[0], amounts[0], selectors[0]
        );

        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "0x123",
                mTokens,
                amounts,
                amounts,
                selectors,
                initHashes,
                0,
                userToLiquidate,
                collateral
            )
        );
    }
}

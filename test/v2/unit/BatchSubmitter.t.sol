// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {stdError} from "forge-std/StdError.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {OperatorStorage} from "src/Operator/OperatorStorage.sol";
import {BatchSubmitter} from "src/mToken/BatchSubmitter.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";

import {BaseBatchSubmitterTest} from "test/v2/utils/BaseBatchSubmitterTest.t.sol";

contract BatchSubmitterTest is BaseBatchSubmitterTest {
    bytes[] internal journals;
    uint256[] internal amounts;
    address[] internal mTokens;
    bytes4[] internal selectors;
    address[] internal receivers;
    bytes32[] internal initHashes;

    bytes4 internal constant OUT_HERE_SELECTOR = ImTokenGateway.outHere.selector;
    bytes4 internal constant MINT_SELECTOR = ImErc20Host.mintExternal.selector;
    bytes4 internal constant REPAY_SELECTOR = ImErc20Host.repayExternal.selector;
    bytes4 internal constant LIQUIDATE_SELECTOR = ImErc20Host.liquidateExternal.selector;

    function setUp() public override {
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

        bytes memory encodedJournals =
            _createBatchJournals(senders, markets, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        receivers = new address[](2);
        receivers[0] = address(this);
        receivers[1] = address(this);

        initHashes = new bytes32[](2);
        initHashes[0] = keccak256(journals[0]);
        initHashes[1] = keccak256(journals[1]);
    }

    modifier whenMarketIsListed(address mToken) {
        if (!operator.isMarketListed(mToken)) {
            operator.supportMarket(mToken);
        }
        _;
    }

    modifier givenSenderHasProofForwarderRole() {
        roles.allowFor(address(this), roles.PROOF_FORWARDER(), true);
        _;
    }

    function _setHostBatch() internal returns (bytes memory encodedJournals) {
        address[] memory hostMarkets = new address[](2);
        hostMarkets[0] = address(mWethHost);
        hostMarkets[1] = address(mUsdcHost);
        mTokens = hostMarkets;

        address[] memory senders = new address[](2);
        senders[0] = address(this);
        senders[1] = address(this);

        encodedJournals =
            _createBatchJournals(senders, hostMarkets, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        initHashes = new bytes32[](2);
        initHashes[0] = keccak256(journals[0]);
        initHashes[1] = keccak256(journals[1]);
    }

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_BatchSubmitter_AddressNotValid_whenRolesZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BatchSubmitter.BatchSubmitter_AddressNotValid.selector);
        new BatchSubmitter(address(0), address(1), address(this));
    }

    function test_unit_constructor_revertsWith_BatchSubmitter_AddressNotValid_whenVerifierZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BatchSubmitter.BatchSubmitter_AddressNotValid.selector);
        new BatchSubmitter(address(1), address(0), address(this));
    }

    ////////////////////////////////////////////////////////////
    //                    UpdateZkVerifier                    //
    ////////////////////////////////////////////////////////////

    function test_unit_updateZkVerifier_revertsWith_BatchSubmitter_AddressNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BatchSubmitter.BatchSubmitter_AddressNotValid.selector);
        batchSubmitter.updateZkVerifier(address(0));
    }

    function test_unit_updateZkVerifier_success_updates() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        ZkVerifier newVerifier = new ZkVerifier(address(this), "0x456", address(verifierMock));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit BatchSubmitter.ZkVerifierUpdated(address(zkVerifier), address(newVerifier));

        batchSubmitter.updateZkVerifier(address(newVerifier));
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(address(batchSubmitter.verifier()), address(newVerifier));
    }

    ////////////////////////////////////////////////////////////
    //                      BatchProcess                      //
    ////////////////////////////////////////////////////////////

    function test_unit_batchProcess_revertsWith_BatchSubmitter_CallerNotAllowed() external {
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

    function test_unit_batchProcess_revertsWith_BatchSubmitter_JournalNotValid()
        external
        givenSenderHasProofForwarderRole
    {
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

    function test_unit_batchProcess_revertsWith_BatchSubmitter_InvalidSelector()
        external
        givenSenderHasProofForwarderRole
    {
        bytes4[] memory invalidSelectors = new bytes4[](1);
        invalidSelectors[0] = bytes4(0x12345678);

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

    function test_unit_batchProcess_revertsWith_JournalsDoNotMatch() external givenSenderHasProofForwarderRole {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory encodedJournals = abi.encode(journals);

        bytes32[] memory invalidInitHashes = new bytes32[](2);
        invalidInitHashes[0] = keccak256(abi.encode("invalid"));
        invalidInitHashes[1] = keccak256(abi.encode("invalid"));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(stdError.indexOOBError);
        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "",
                mTokens,
                amounts,
                amounts,
                selectors,
                invalidInitHashes,
                1,
                new address[](0),
                new address[](0)
            )
        );
    }

    function test_unit_batchProcess_revertsWith_AmountsLengthMismatch() external givenSenderHasProofForwarderRole {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256[] memory invalidAmounts = new uint256[](1);
        invalidAmounts[0] = 1 ether;

        bytes memory encodedJournals = abi.encode(journals);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(stdError.indexOOBError);
        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "",
                mTokens,
                invalidAmounts,
                amounts,
                selectors,
                initHashes,
                0,
                new address[](0),
                new address[](0)
            )
        );
    }

    function test_unit_batchProcess_revertsWith_TokenAmountsLengthMismatch() external givenSenderHasProofForwarderRole {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256[] memory invalidTokenAmounts = new uint256[](1);
        invalidTokenAmounts[0] = 1 ether;

        bytes memory encodedJournals = abi.encode(journals);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(stdError.indexOOBError);
        batchSubmitter.batchProcess(
            BatchSubmitter.BatchProcessMsg(
                receivers,
                encodedJournals,
                "",
                mTokens,
                amounts,
                invalidTokenAmounts,
                selectors,
                initHashes,
                0,
                new address[](0),
                new address[](0)
            )
        );
    }

    function test_unit_batchProcess_success_marketIsNotListed_failed() external givenSenderHasProofForwarderRole {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mErc20Host mErc20HostImpl = new mErc20Host();
        bytes memory initData = abi.encodeWithSelector(
            mErc20Host.initialize.selector,
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Unlisted WETH",
            "umWETH",
            18,
            payable(address(this)),
            address(zkVerifier),
            address(roles)
        );
        ERC1967Proxy unlistedProxy = new ERC1967Proxy(address(mErc20HostImpl), initData);
        mErc20Host unlistedHost = mErc20Host(address(unlistedProxy));

        address[] memory unlistedMarkets = new address[](1);
        unlistedMarkets[0] = address(unlistedHost);
        mTokens = unlistedMarkets;

        selectors = new bytes4[](1);
        selectors[0] = MINT_SELECTOR;

        receivers = new address[](1);
        receivers[0] = address(this);

        amounts = new uint256[](1);
        amounts[0] = 1 ether;

        address[] memory senders = new address[](1);
        senders[0] = address(this);

        bytes memory encodedJournals =
            _createBatchJournals(senders, unlistedMarkets, amounts, TEST_SOURCE_CHAIN_ID, uint32(block.chainid), true);
        journals = abi.decode(encodedJournals, (bytes[]));

        initHashes = new bytes32[](1);
        initHashes[0] = keccak256(journals[0]);

        bytes memory reason = abi.encodeWithSelector(OperatorStorage.Operator_MarketNotListed.selector);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit BatchSubmitter.BatchProcessFailed(
            initHashes[0], receivers[0], mTokens[0], amounts[0], amounts[0], selectors[0], reason
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

    function test_unit_batchProcess_success_outHere()
        external
        givenSenderHasProofForwarderRole
        whenMarketIsListed(address(mWethHost))
    {
        bytes memory encodedJournals = abi.encode(journals);

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

    function test_unit_batchProcess_success_mintHost()
        external
        givenSenderHasProofForwarderRole
        whenMarketIsListed(address(mWethHost))
    {
        selectors = new bytes4[](2);
        selectors[0] = MINT_SELECTOR;
        selectors[1] = MINT_SELECTOR;

        bytes memory encodedJournals = _setHostBatch();

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

    function test_unit_batchProcess_success_repayHost()
        external
        givenSenderHasProofForwarderRole
        whenMarketIsListed(address(mWethHost))
    {
        selectors = new bytes4[](2);
        selectors[0] = REPAY_SELECTOR;
        selectors[1] = REPAY_SELECTOR;

        bytes memory encodedJournals = _setHostBatch();

        _getTokens(weth, address(this), amounts[0]);
        weth.approve(address(mWethHost), amounts[0]);
        mWethHost.mint(amounts[0], address(this), 0);

        _getTokens(usdc, address(this), amounts[1]);
        usdc.approve(address(mUsdcHost), amounts[1]);
        mUsdcHost.mint(amounts[1], address(this), 0);

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

    function test_unit_batchProcess_success_liquidateHost()
        external
        givenSenderHasProofForwarderRole
        whenMarketIsListed(address(mWethHost))
    {
        selectors = new bytes4[](2);
        selectors[0] = LIQUIDATE_SELECTOR;
        selectors[1] = LIQUIDATE_SELECTOR;

        bytes memory encodedJournals = _setHostBatch();

        _getTokens(weth, address(this), amounts[0]);
        weth.approve(address(mWethHost), amounts[0]);
        mWethHost.mint(amounts[0], address(this), 0);

        _getTokens(usdc, address(this), amounts[1]);
        usdc.approve(address(mUsdcHost), amounts[1]);
        mUsdcHost.mint(amounts[1], address(this), 0);

        address[] memory usersToLiquidate = new address[](2);
        usersToLiquidate[0] = users.bob;
        usersToLiquidate[1] = users.bob;

        address[] memory collateral = new address[](2);
        collateral[0] = address(mWethHost);
        collateral[1] = address(mUsdcHost);

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
                usersToLiquidate,
                collateral
            )
        );
    }
}

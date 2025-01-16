// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Base_Unit_Test} from "../../Base_Unit_Test.t.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {BatchSubmitter} from "src/mToken/BatchSubmitter.sol";
import {Risc0VerifierMock} from "../../mocks/Risc0VerifierMock.sol";

abstract contract BatchSubmitter_Unit_Shared is Base_Unit_Test {
    mTokenGateway public mWethExtension;
    mTokenGateway public mUsdcExtension;
    BatchSubmitter public batchSubmitter;
    Risc0VerifierMock public verifierMock;

    uint32 internal constant TEST_SOURCE_CHAIN_ID = 59144; // Linea chain ID for tests

    function setUp() public virtual override {
        super.setUp();

        verifierMock = new Risc0VerifierMock();
        vm.label(address(verifierMock), "verifierMock");

        // Deploy mToken gateways
        mWethExtension = new mTokenGateway(
            payable(address(this)),
            address(weth),
            address(roles),
            address(verifierMock)
        );
        vm.label(address(mWethExtension), "mWethExtension");

        mUsdcExtension = new mTokenGateway(
            payable(address(this)),
            address(usdc),
            address(roles),
            address(verifierMock)
        );
        vm.label(address(mUsdcExtension), "mUsdcExtension");

        // Deploy batch submitter
        batchSubmitter = new BatchSubmitter(
            address(roles),
            address(verifierMock)
        );
        vm.label(address(batchSubmitter), "BatchSubmitter");

        // Give BatchSubmitter the PROOF_BATCH_FORWARDER role
        roles.allowFor(address(batchSubmitter), roles.PROOF_BATCH_FORWARDER(), true);
    }

    /**
     * @notice Creates a batch of journals for multiple senders, markets and amounts
     * @param senders Array of sender addresses
     * @param markets Array of market addresses
     * @param amounts Array of amounts
     * @param srcChainId Source chain ID
     * @param dstChainId Destination chain ID
     * @return bytes Encoded array of journals
     */
    function _createBatchJournals(
        address[] memory senders,
        address[] memory markets,
        uint256[] memory amounts,
        uint32 srcChainId,
        uint32 dstChainId
    ) internal pure returns (bytes memory) {
        require(
            senders.length == markets.length && markets.length == amounts.length,
            "BatchSubmitter_Unit_Shared: Array lengths mismatch"
        );

        bytes[] memory journals = new bytes[](senders.length);
        
        for (uint256 i = 0; i < senders.length;) {
            journals[i] = abi.encodePacked(
                senders[i],
                markets[i],
                amounts[i],
                amounts[i],
                srcChainId,
                dstChainId
            );

            unchecked { ++i; }
        }

        return abi.encode(journals);
    }
} 
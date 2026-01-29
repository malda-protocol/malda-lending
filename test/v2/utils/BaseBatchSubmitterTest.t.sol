// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {BaseProtocolTest} from "./BaseProtocolTest.t.sol";

import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {BatchSubmitter} from "src/mToken/BatchSubmitter.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";

import {Risc0VerifierMock} from "test/mocks/Risc0VerifierMock.sol";

abstract contract BaseBatchSubmitterTest is BaseProtocolTest {
    mTokenGateway public mWethExtension;
    mTokenGateway public mUsdcExtension;
    BatchSubmitter public batchSubmitter;
    Risc0VerifierMock public verifierMock;
    mErc20Host public mWethHost;
    mErc20Host public mUsdcHost;
    ZkVerifier public zkVerifier;

    uint32 internal constant TEST_SOURCE_CHAIN_ID = 59144;

    function setUp() public virtual override {
        super.setUp();

        verifierMock = new Risc0VerifierMock();
        vm.label(address(verifierMock), "verifierMock");

        zkVerifier = new ZkVerifier(address(this), "0x123", address(verifierMock));
        vm.label(address(zkVerifier), "ZkVerifier");

        mTokenGateway gatewayImpl = new mTokenGateway();

        bytes memory mWethGatewayInitData = abi.encodeWithSelector(
            mTokenGateway.initialize.selector,
            payable(address(this)),
            address(weth),
            address(roles),
            address(blacklister),
            address(zkVerifier)
        );
        ERC1967Proxy mWethGatewayProxy = new ERC1967Proxy(address(gatewayImpl), mWethGatewayInitData);
        mWethExtension = mTokenGateway(address(mWethGatewayProxy));
        vm.label(address(mWethExtension), "mWethExtension");

        bytes memory mUsdcGatewayInitData = abi.encodeWithSelector(
            mTokenGateway.initialize.selector,
            payable(address(this)),
            address(usdc),
            address(roles),
            address(blacklister),
            address(zkVerifier)
        );
        ERC1967Proxy mUsdcGatewayProxy = new ERC1967Proxy(address(gatewayImpl), mUsdcGatewayInitData);
        mUsdcExtension = mTokenGateway(address(mUsdcGatewayProxy));
        vm.label(address(mUsdcExtension), "mUsdcExtension");

        mErc20Host mErc20HostImpl = new mErc20Host();
        bytes memory mWethHostInitData = abi.encodeWithSelector(
            mErc20Host.initialize.selector,
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Malda WETH",
            "mWETH",
            18,
            payable(address(this)),
            address(zkVerifier),
            address(roles)
        );
        ERC1967Proxy mWethHostProxy = new ERC1967Proxy(address(mErc20HostImpl), mWethHostInitData);
        mWethHost = mErc20Host(address(mWethHostProxy));
        vm.label(address(mWethHost), "mWethHost");

        bytes memory mUsdcHostInitData = abi.encodeWithSelector(
            mErc20Host.initialize.selector,
            address(usdc),
            address(operator),
            address(interestModel),
            1e18,
            "Malda USDC",
            "mUSDC",
            6,
            payable(address(this)),
            address(zkVerifier),
            address(roles)
        );
        ERC1967Proxy mUsdcHostProxy = new ERC1967Proxy(address(mErc20HostImpl), mUsdcHostInitData);
        mUsdcHost = mErc20Host(address(mUsdcHostProxy));
        vm.label(address(mUsdcHost), "mUsdcHost");

        batchSubmitter = new BatchSubmitter(address(roles), address(zkVerifier), address(this));
        vm.label(address(batchSubmitter), "BatchSubmitter");

        roles.allowFor(address(batchSubmitter), roles.PROOF_BATCH_FORWARDER(), true);

        mWethHost.updateAllowedChain(uint32(block.chainid), true);
        mUsdcHost.updateAllowedChain(uint32(block.chainid), true);
        mWethHost.updateAllowedChain(TEST_SOURCE_CHAIN_ID, true);
        mUsdcHost.updateAllowedChain(TEST_SOURCE_CHAIN_ID, true);
        operator.supportMarket(address(mWethHost));
        operator.supportMarket(address(mUsdcHost));
    }

    function _createBatchJournals(
        address[] memory senders,
        address[] memory markets,
        uint256[] memory amounts,
        uint32 srcChainId,
        uint32 dstChainId,
        bool l1Inclusion
    ) internal pure returns (bytes memory) {
        require(senders.length == markets.length && markets.length == amounts.length, "Array lengths mismatch");

        bytes[] memory journals = new bytes[](senders.length);
        for (uint256 i = 0; i < senders.length;) {
            journals[i] =
                abi.encodePacked(senders[i], markets[i], amounts[i], amounts[i], srcChainId, dstChainId, l1Inclusion);
            unchecked {
                ++i;
            }
        }

        return abi.encode(journals);
    }

    function _repayPrerequisites(address market, uint256 amount) internal {
        _getTokens(weth, address(this), amount);
        weth.approve(market, amount);
        mErc20Host(market).mint(amount, address(this), amount);
    }
}

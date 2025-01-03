// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILayerZeroReceiverV2} from "src/interfaces/external/layerzero/v2/ILayerZeroReceiverV2.sol";
import {
    ILayerZeroEndpointV2,
    MessagingParams,
    Origin,
    MessagingFee
} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";

import {IRoles} from "src/interfaces/IRoles.sol";
import {IBridge} from "src/interfaces/IBridge.sol";
import {ImTokenMinimal} from "src/interfaces/ImToken.sol";

contract LZMessageOnlyBridge is IBridge, ILayerZeroReceiverV2 {
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------
    IRoles public roles;
    ILayerZeroEndpointV2 public endpoint;
    mapping(uint32 eId => bytes32 peer) public peers;
    mapping(uint256 dstChainId => uint32 eId) public chainToEid;
    mapping(bytes32 guid => bool processed) public processedOperations;

    uint64 private constant SENDER = 1; // LZ Sender versionss
    uint64 private constant RECEIVER = 2; // LZ Receiver version

    // ----------- EVENTS ------------
    event PeerSet(uint32 indexed eId, bytes32 peer);
    event LayerZeroEndpointUpdated(address indexed oldVal, address indexed newVal);
    event MsgSent(uint32 dstChainId, bytes message, uint256 gasLimit, address indexed refundAddress);
    event Rebalanced(address indexed market, uint256 amount);

    error LZBridge_NotEnoughFees();
    error LZBridge_NotAuthorized();
    error LZBridge_PeerNotRegistered();
    error LZBridge_ChainNotRegistered();
    error LZBridge_OperationAlreadyProcessed();

    constructor(address _roles) {
        roles = IRoles(_roles);
    }

    modifier onlyBridgeConfigurator() {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert LZBridge_NotAuthorized();
        _;
    }

    modifier onlyRebalancer() {
        if (!roles.isAllowedFor(msg.sender, roles.REBALANCER())) revert LZBridge_NotAuthorized();
        _;
    }

    // ----------- OWNER ------------
    /**
     * @notice set LZ endpoint address
     * @param _endpoint the new LZ endpoint
     */
    function setLZEndpoint(address _endpoint) external onlyBridgeConfigurator {
        emit LayerZeroEndpointUpdated(address(endpoint), _endpoint);
        endpoint = ILayerZeroEndpointV2(_endpoint);
    }

    /**
     * @notice updates cross chain peer
     * @param _eId the LZ endpoint id
     * @param _peer the peer address
     */
    function updatePeer(uint32 _eId, bytes32 _peer) external onlyBridgeConfigurator {
        peers[_eId] = _peer;
        emit PeerSet(_eId, _peer);
    }


    // ----------- VIEW ------------
    /**
     * @inheritdoc IBridge
     * @dev use `getOptionsData` for `_bridgeData`
     */
    function getFee(uint32 _dstChainId, bytes memory _message, bytes memory _bridgeData)
        external
        view
        returns (uint256)
    {
        require(_dstChainId > 0, LZBridge_ChainNotRegistered());
        require(peers[_dstChainId] != bytes32(0), LZBridge_PeerNotRegistered());
        MessagingFee memory fees = _getFee(_dstChainId, _message, _bridgeData);
        return fees.nativeFee; // no option to pay in LZ token with this version
    }
    /**
     * @notice builds bridge data
     * @param gasLimit `lzSend` operation gas limit
     */

    function getOptionsData(uint256 gasLimit) public pure returns (bytes memory) {
        return abi.encodePacked(uint16(1), gasLimit); // send
    }

    /// @dev without order enforcer; needed for ILayerZeroReceiverV2
    function nextNonce(uint32, bytes32) external pure override returns (uint64 nonce) {
        return 0;
    }

    /// @dev check if path is allowed; needed for ILayerZeroReceiverV2
    function allowInitializePath(Origin calldata origin) external view override returns (bool) {
        return peers[origin.srcEid] == origin.sender;
    }

    // ----------- EXTERNAL ------------
    /**
     * @inheritdoc IBridge
     */
    function sendMsg(uint32 _dstChainId, address, bytes memory _message, bytes memory _bridgeData)
        external
        payable
        onlyRebalancer
    {
        require(_dstChainId > 0, LZBridge_ChainNotRegistered());
        require(peers[_dstChainId] != bytes32(0), LZBridge_PeerNotRegistered());

        MessagingFee memory fees = _getFee(_dstChainId, _message, _bridgeData);
        if (msg.value < fees.nativeFee || fees.lzTokenFee != 0) revert LZBridge_NotEnoughFees();

        (uint256 gasLimit, address refundAddress) = abi.decode(_bridgeData, (uint256, address));
        bytes memory options = getOptionsData(gasLimit);

        endpoint.send{value: msg.value}(MessagingParams(_dstChainId, peers[_dstChainId], _message, options, false), refundAddress);

        emit MsgSent(_dstChainId, _message, gasLimit, refundAddress);
    }

    /// @inheritdoc ILayerZeroReceiverV2
    function lzReceive(Origin calldata _origin, bytes32 _guid, bytes calldata _message, address, bytes calldata)
        external
        payable
        override
    {
        require(!processedOperations[_guid], LZBridge_OperationAlreadyProcessed());
        processedOperations[_guid] = true;
        require(peers[_origin.srcEid] == _origin.sender, LZBridge_PeerNotRegistered());

        (address market, uint256 amount) = abi.decode(_message, (address, uint256));
        address _underlying = ImTokenMinimal(market).underlying();
        if (amount > 0) {
            IERC20(_underlying).safeTransfer(market, amount);
        }

        emit Rebalanced(market, amount);

        //TODO: check if we need anything else
    }

    function retryPayload(bytes calldata _data) external payable {
        (Origin memory origin, address receiver, bytes32 guid, bytes memory message, bytes memory extraData) =
            abi.decode(_data, (Origin, address, bytes32, bytes, bytes));

        endpoint.lzReceive{value: msg.value}(origin, receiver, guid, message, extraData);
    }

    // ----------- PRIVATE ------------
    function _getFee(uint32 dstEid, bytes memory _message, bytes memory _options)
        private
        view
        returns (MessagingFee memory fees)
    {
        return endpoint.quote(MessagingParams(dstEid, peers[dstEid], _message, _options, false), address(this));
    }
}

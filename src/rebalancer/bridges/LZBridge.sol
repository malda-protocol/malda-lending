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

//TODO: add natspec and move events and errors to the interface
contract LZBridge is IBridge, ILayerZeroReceiverV2 {
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------
    IRoles public roles;
    ILayerZeroEndpointV2 public endpoint;
   
    uint64 private constant SENDER = 1; // LZ Sender version
    uint64 private constant RECEIVER = 2; // LZ Receiver version

    event LayerZeroEndpointUpdated(address indexed oldVal, address indexed newVal);

    constructor(address _roles) {
        roles = IRoles(_roles);
    }

    modifier onlyBridgeConfigurator() {
        // TODO: add
        _;
    }

    modifier onlyRebalancer() {
        // TODO: add
        _;
    }

    function nextNonce(uint32, bytes32) external pure override returns (uint64 nonce) {
        return 0;
    }

    function sendMsg(uint256 _dstChainId, bytes memory _message, bytes memory _bridgeData) external payable {
        
    } 

    function lzReceive(Origin calldata _origin, bytes32 _guid, bytes calldata _message, address, bytes calldata)
        external
        payable
        override
    {

    }

    function allowInitializePath(Origin calldata origin) external view override returns (bool) {
    }

     function getFee(uint256 _dstChainId, bytes memory _message, bytes memory _bridgeData)
        external
        view
        returns (uint256)
    {

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

}

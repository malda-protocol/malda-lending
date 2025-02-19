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

import {SafeApprove} from "src/libraries/SafeApprove.sol";

import {IBridge} from "src/interfaces/IBridge.sol";
import {IConnext} from "src/interfaces/external/connext/IConnext.sol";

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";

contract ConnextBridge is BaseBridge, IBridge {
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------
    IConnext public immutable connext;
    mapping(uint32 => uint32) public domainIds;

    struct DecodedMessage {
        address market;
        address delegate;
        uint256 amount;
        uint256 slippage;
        uint256 relayerFee;
    }

    // ----------- EVENTS ------------
    event MsgSent(uint256 indexed dstChainId, address indexed market, uint256 amountLD, uint256 slippage, bytes32 id);
    event DomainIdSet(uint32 indexed dstId, uint32 indexed domainId);

    // ----------- ERRORS ------------
    error Connext_NotEnoughFees();
    error Connext_NotImplemented();
    error Connext_DomainIdNotSet();

    constructor(address _roles, address _connext) BaseBridge(_roles) {
        connext = IConnext(_connext);
    }
    // ----------- OWNER ------------
    /**
     * @notice Set domain id
    */
    function setDomainId(uint32 _dstId, uint32 _domainId) external onlyBridgeConfigurator {
        domainIds[_dstId] = _domainId;
        emit DomainIdSet(_dstId, _domainId);
    }

    // ----------- VIEW ------------
    /**
     * @inheritdoc IBridge
     */
    function getFee(uint32, bytes memory, bytes memory) external pure returns (uint256) {
        // need to use Connext API
        revert Connext_NotImplemented();
    }

    // ----------- EXTERNAL ------------
    /**
     * @inheritdoc IBridge
     */
    function sendMsg(uint32 _dstChainId, address _token, bytes memory _message, bytes memory)
        external
        payable
        onlyRebalancer
    {
        // decode message & checks
        DecodedMessage memory msgData = _decodeMessage(_message);
        require(msgData.amount >= minTransfer && msgData.amount <= maxTransfer, BaseBridge_AmountNotValid());
        require(msg.value >= msgData.relayerFee, Connext_NotEnoughFees());
        require(domainIds[_dstChainId] > 0, Connext_DomainIdNotSet());

        // retrieve tokens from `Rebalancer`
        IERC20(_token).safeTransferFrom(msg.sender, address(this), msgData.amount);

        // approve and send with Connext
        SafeApprove.safeApprove(_token, address(connext), msgData.amount);
        bytes32 id = connext.xcall{value: msgData.relayerFee}(
            domainIds[_dstChainId], // _destination: Domain ID of the destination chain
            msgData.market, // _to: address receiving the funds on the destination
            _token, // _asset: address of the token contract
            msgData.delegate, // _delegate: address that can revert or forceLocal on destination
            msgData.amount, // _amount: amount of tokens to transfer
            msgData.slippage, // _slippage: the maximum amount of slippage the user will accept in BPS (e.g. 30 = 0.3%)
            "" // _callData: empty bytes because we're only sending funds
        );
        emit MsgSent(_dstChainId, msgData.market, msgData.amount, msgData.slippage, id);
    }

    // ----------- PRIVATE ------------
    function _decodeMessage(bytes memory _message) private pure returns (DecodedMessage memory) {
        (address market, address delegate, uint256 amount, uint256 slippage, uint256 relayerFee) =
            abi.decode(_message, (address, address, uint256, uint256, uint256));

        return DecodedMessage(market, delegate, amount, slippage, relayerFee);
    }
}

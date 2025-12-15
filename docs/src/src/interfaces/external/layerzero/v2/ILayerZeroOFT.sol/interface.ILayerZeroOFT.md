# ILayerZeroOFT
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\external\layerzero\v2\ILayerZeroOFT.sol)

*Interface for the OftChain (OFT) token.*

*Does not inherit ERC20 to accommodate usage by OFTAdapter as well.*

*This specific interface ID is '0x02e49c2c'.*


## Functions
### oftVersion

Retrieves interfaceID and the version of the OFT.

*interfaceId: This specific interface ID is '0x02e49c2c'.*

*version: Indicates a cross-chain compatible msg encoding with other OFTs.*

*If a new feature is added to the OFT cross-chain msg encoding, the version will be incremented.
ie. localOFT version(x,1) CAN send messages to remoteOFT version(x,1)*


```solidity
function oftVersion() external view returns (bytes4 interfaceId, uint64 version);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`interfaceId`|`bytes4`|The interface ID.|
|`version`|`uint64`|The version.|


### token

Retrieves the address of the token associated with the OFT.


```solidity
function token() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|token The address of the ERC20 token implementation.|


### approvalRequired

Indicates whether the OFT contract requires approval of the 'token()' to send.

*Allows things like wallet implementers to determine integration requirements,
without understanding the underlying token implementation.*


```solidity
function approvalRequired() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|requiresApproval Needs approval of the underlying token implementation.|


### sharedDecimals

Retrieves the shared decimals of the OFT.


```solidity
function sharedDecimals() external view returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|sharedDecimals The shared decimals of the OFT.|


### quoteOFT

Provides a quote for OFT-related operations.


```solidity
function quoteOFT(SendParam calldata _sendParam)
    external
    view
    returns (OFTLimit memory, OFTFeeDetail[] memory oftFeeDetails, OFTReceipt memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sendParam`|`SendParam`|The parameters for the send operation.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`OFTLimit`|limit The OFT limit information.|
|`oftFeeDetails`|`OFTFeeDetail[]`|The details of OFT fees.|
|`<none>`|`OFTReceipt`|receipt The OFT receipt information.|


### quoteSend

Provides a quote for the send() operation.

*MessagingFee: LayerZero msg fee
- nativeFee: The native fee.
- lzTokenFee: The lzToken fee.*


```solidity
function quoteSend(SendParam calldata _sendParam, bool _payInLzToken) external view returns (MessagingFee memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sendParam`|`SendParam`|The parameters for the send() operation.|
|`_payInLzToken`|`bool`|Flag indicating whether the caller is paying in the LZ token.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`MessagingFee`|fee The calculated LayerZero messaging fee from the send() operation.|


### send

Executes the send() operation.

*MessagingReceipt: LayerZero msg receipt
- guid: The unique identifier for the sent message.
- nonce: The nonce of the sent message.
- fee: The LayerZero fee incurred for the message.*


```solidity
function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
    external
    payable
    returns (MessagingReceipt memory, OFTReceipt memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sendParam`|`SendParam`|The parameters for the send operation.|
|`_fee`|`MessagingFee`|The fee information supplied by the caller. - nativeFee: The native fee. - lzTokenFee: The lzToken fee.|
|`_refundAddress`|`address`|The address to receive any excess funds from fees etc. on the src.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`MessagingReceipt`|receipt The LayerZero messaging receipt from the send() operation.|
|`<none>`|`OFTReceipt`|oftReceipt The OFT receipt information.|


## Events
### OFTSent

```solidity
event OFTSent(
    bytes32 indexed guid, uint32 dstEid, address indexed fromAddress, uint256 amountSentLD, uint256 amountReceivedLD
);
```

### OFTReceived

```solidity
event OFTReceived(bytes32 indexed guid, uint32 srcEid, address indexed toAddress, uint256 amountReceivedLD);
```

## Errors
### InvalidLocalDecimals

```solidity
error InvalidLocalDecimals();
```

### SlippageExceeded

```solidity
error SlippageExceeded(uint256 amountLD, uint256 minAmountLD);
```


# EverclearBridge
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/rebalancer/bridges/EverclearBridge.sol)

**Inherits:**
[BaseBridge](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/rebalancer/bridges/BaseBridge.sol/abstract.BaseBridge.md), [IBridge](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/interfaces/IBridge.sol/interface.IBridge.md)

**Author:**
Malda Protocol

Cross-chain bridge using Everclear protocol for intent-based transfers


## State Variables
### everclearFeeAdapter
Everclear fee adapter contract


```solidity
IFeeAdapter public everclearFeeAdapter
```


## Functions
### constructor

Initializes the Everclear bridge


```solidity
constructor(address _roles, address _feeAdapter) BaseBridge(_roles);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_roles`|`address`|Roles contract address|
|`_feeAdapter`|`address`|Everclear fee adapter address|


### sendMsg

rebalance through bridge


```solidity
function sendMsg(
    uint256 _extractedAmount,
    address _market,
    uint32 _dstChainId,
    address _token,
    bytes calldata _message,
    bytes calldata /* _bridgeData */
) external payable onlyRebalancer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_extractedAmount`|`uint256`|extracted amount for rebalancing|
|`_market`|`address`|destination address|
|`_dstChainId`|`uint32`|destination chain id|
|`_token`|`address`|the token to rebalance|
|`_message`|`bytes`|operation message data|
|`<none>`|`bytes`||


### getFee

computes fee for bridge operation


```solidity
function getFee(uint32, bytes calldata, bytes calldata) external pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`||
|`<none>`|`bytes`||
|`<none>`|`bytes`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|fee Computed bridge fee|


### _decodeIntent

Decodes an intent message returned by the Everclear intents API into structured parameters.


- The input `message` is the raw ABI-encoded calldata of a `FeeAdapter.newIntent` call.
- The first 4 bytes are the function selector, which are skipped.
- The remaining bytes encode the primary intent parameters followed by `FeeParams`.
- Because `FeeParams` is a dynamic struct appended at the end, its data must be located by
reading its offset and decoding separately.
Layout of `FeeAdapter.newIntent` calldata after the selector:
```
destinations (uint32[])   at offset 0x00
receiver (bytes32)        at offset 0x20
inputAsset (address)      at offset 0x40
outputAsset (bytes32)     at offset 0x60
amount (uint256)          at offset 0x80
maxFee (uint24)           at offset 0xa0
ttl (uint48)              at offset 0xc0
data (bytes)              at offset 0xe0
feeParams (FeeParams)     at offset 0x100 (9th arg → pointer)
```
Since each static argument occupies a 32-byte slot, the pointer to `feeParams`
lives at offset `0x100` (256 bytes) after the selector is removed.


```solidity
function _decodeIntent(bytes memory message) internal pure returns (IntentParams memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`message`|`bytes`|ABI-encoded calldata for `FeeAdapter.newIntent`.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IntentParams`|Decoded `IntentParams` struct with both core parameters and nested `FeeParams`.|


### _extractFeeParams

Extracts the nested `FeeParams` struct from ABI-encoded `intentData`.


- `FeeParams` is the 9th parameter of `FeeAdapter.newIntent` and therefore stored as a pointer at offset `0x100`.
- The selector has already been removed, so the pointer is read at byte position `0x100` (256 bytes).
- The pointer gives the offset to the start of the `FeeParams` struct relative to the start of intentData.
- Within `FeeParams`, the layout is:
```
fee      (uint256) at +0x00
deadline (uint256) at +0x20
sig      (bytes)   at +0x40 (stored as offset → length → data)
```
- The `sig` field is dynamic, so we read its offset (at +0x40) relative to the `FeeParams` base,
then read the length at that offset, then slice out the actual signature bytes.


```solidity
function _extractFeeParams(bytes memory intentData)
    private
    pure
    returns (uint256 fee, uint256 deadline, bytes memory sig);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`intentData`|`bytes`|ABI-encoded calldata without selector, containing intent arguments.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|The fee value.|
|`deadline`|`uint256`|The signature deadline.|
|`sig`|`bytes`|The validator/relayer signature.|


## Events
### MsgSent
Emitted when a message is sent via Everclear


```solidity
event MsgSent(uint256 indexed dstChainId, address indexed market, uint256 amountLD, bytes32 id);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstChainId`|`uint256`|Destination chain ID|
|`market`|`address`|Market address|
|`amountLD`|`uint256`|Amount in local decimals|
|`id`|`bytes32`|Intent identifier|

### RebalancingReturnedToMarket
Emitted when excess rebalancing funds are returned to the market


```solidity
event RebalancingReturnedToMarket(address indexed market, uint256 toReturn, uint256 extracted);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`market`|`address`|Market address|
|`toReturn`|`uint256`|Amount returned|
|`extracted`|`uint256`|Amount originally extracted|

## Errors
### Everclear_TokenMismatch
Error thrown when provided token does not match expected asset


```solidity
error Everclear_TokenMismatch();
```

### Everclear_NotImplemented
Error thrown when a feature is not implemented


```solidity
error Everclear_NotImplemented();
```

### Everclear_MaxFeeExceeded
Error thrown when maximum fee is exceeded


```solidity
error Everclear_MaxFeeExceeded();
```

### Everclear_AddressNotValid
Error thrown when provided address is invalid


```solidity
error Everclear_AddressNotValid();
```

### Everclear_DestinationNotValid
Error thrown when provided destination is invalid


```solidity
error Everclear_DestinationNotValid();
```

### Everclear_DestinationsLengthMismatch
Error thrown when destination arrays have mismatched length


```solidity
error Everclear_DestinationsLengthMismatch();
```

## Structs
### IntentParams

```solidity
struct IntentParams {
    uint32[] destinations;
    bytes32 receiver;
    address inputAsset;
    bytes32 outputAsset;
    uint256 amount;
    uint24 maxFee;
    uint48 ttl;
    bytes data;
    IFeeAdapter.FeeParams feeParams;
}
```


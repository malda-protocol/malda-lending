# ILayerZeroEndpoint
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\external\layerzero\ILayerZeroEndpoint.sol)

**Inherits:**
[ILayerZeroUserApplicationConfig](/src\interfaces\external\layerzero\ILayerZeroUserApplicationConfig.sol\interface.ILayerZeroUserApplicationConfig.md)

*is imported from
(https://github.com/LayerZero-Labs/LayerZero/blob/main/contracts/interfaces/ILayerZeroEndpoint.sol)*


## Functions
### send


```solidity
function send(
    uint16 dstChainId_,
    bytes calldata destination_,
    bytes calldata payload_,
    address payable refundAddress_,
    address zroPaymentAddress_,
    bytes calldata adapterParams_
) external payable;
```

### receivePayload


```solidity
function receivePayload(
    uint16 srcChainId_,
    bytes calldata srcAddress_,
    address dstAddress_,
    uint64 nonce_,
    uint256 gasLimit_,
    bytes calldata payload_
) external;
```

### getInboundNonce


```solidity
function getInboundNonce(uint16 srcChainId_, bytes calldata srcAddress_) external view returns (uint64);
```

### getOutboundNonce


```solidity
function getOutboundNonce(uint16 dstChainId_, address srcAddress_) external view returns (uint64);
```

### estimateFees


```solidity
function estimateFees(
    uint16 dstChainId_,
    address userApplication_,
    bytes calldata payload_,
    bool _payInZRO,
    bytes calldata _adapterParam
) external view returns (uint256 nativeFee, uint256 zroFee);
```

### getChainId


```solidity
function getChainId() external view returns (uint16);
```

### retryPayload


```solidity
function retryPayload(uint16 srcChainId_, bytes calldata srcAddress_, bytes calldata payload_) external;
```

### hasStoredPayload


```solidity
function hasStoredPayload(uint16 srcChainId_, bytes calldata srcAddress_) external view returns (bool);
```

### getSendLibraryAddress


```solidity
function getSendLibraryAddress(address userApplication_) external view returns (address);
```

### getReceiveLibraryAddress


```solidity
function getReceiveLibraryAddress(address userApplication_) external view returns (address);
```

### isSendingPayload


```solidity
function isSendingPayload() external view returns (bool);
```

### isReceivingPayload


```solidity
function isReceivingPayload() external view returns (bool);
```

### getConfig


```solidity
function getConfig(uint16 version_, uint16 chainId_, address userApplication_, uint256 configType_)
    external
    view
    returns (bytes memory);
```

### getSendVersion


```solidity
function getSendVersion(address userApplication_) external view returns (uint16);
```

### getReceiveVersion


```solidity
function getReceiveVersion(address userApplication_) external view returns (uint16);
```


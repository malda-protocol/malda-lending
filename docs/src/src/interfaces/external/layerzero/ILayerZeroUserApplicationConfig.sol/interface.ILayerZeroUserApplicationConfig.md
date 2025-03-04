# ILayerZeroUserApplicationConfig
[Git Source](https://github.com/malda-protocol/malda-lending/blob/6ea8fcbab45a04b689cc49c81c736245cab92c98/src\interfaces\external\layerzero\ILayerZeroUserApplicationConfig.sol)

*is imported from
(https://github.com/LayerZero-Labs/LayerZero/blob/main/contracts/interfaces/ILayerZeroUserApplicationConfig.sol)*


## Functions
### setConfig


```solidity
function setConfig(uint16 _version, uint16 _chainId, uint256 _configType, bytes calldata _config) external;
```

### setSendVersion


```solidity
function setSendVersion(uint16 _version) external;
```

### setReceiveVersion


```solidity
function setReceiveVersion(uint16 _version) external;
```

### forceResumeReceive


```solidity
function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external;
```


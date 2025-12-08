# ILayerZeroUserApplicationConfig
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/interfaces/external/layerzero/ILayerZeroUserApplicationConfig.sol)

is imported from
(https://github.com/LayerZero-Labs/LayerZero/blob/main/contracts/interfaces/ILayerZeroUserApplicationConfig.sol)


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


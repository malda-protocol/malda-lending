# CREATE3
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\libraries\CREATE3.sol)

**Authors:**
Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/CREATE3.sol), Modified from 0xSequence (https://github.com/0xSequence/create3/blob/master/contracts/Create3.sol)

Deploy to deterministic addresses without an initcode factor.


## State Variables
### PROXY_BYTECODE

```solidity
bytes internal constant PROXY_BYTECODE = hex"67363d3d37363d34f03d5260086018f3";
```


### PROXY_BYTECODE_HASH

```solidity
bytes32 internal constant PROXY_BYTECODE_HASH = keccak256(PROXY_BYTECODE);
```


## Functions
### deploy


```solidity
function deploy(bytes32 salt, bytes memory creationCode, uint256 value) internal returns (address deployed);
```

### getDeployed


```solidity
function getDeployed(bytes32 salt) internal view returns (address);
```


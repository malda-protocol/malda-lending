# Deployer
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\utils\Deployer.sol)


## State Variables
### admin

```solidity
address public admin;
```


## Functions
### constructor


```solidity
constructor();
```

### receive


```solidity
receive() external payable;
```

### saveEth


```solidity
function saveEth() external;
```

### precompute


```solidity
function precompute(bytes32 salt) external view returns (address);
```

### create


```solidity
function create(bytes32 salt, bytes memory code) external payable returns (address);
```


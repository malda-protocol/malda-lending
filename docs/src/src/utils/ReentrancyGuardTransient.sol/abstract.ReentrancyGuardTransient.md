# ReentrancyGuardTransient
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\utils\ReentrancyGuardTransient.sol)

*Variant of {ReentrancyGuard} that uses transient storage.
NOTE: This variant only works on networks where EIP-1153 is available.
_Available since v5.1._*


## State Variables
### REENTRANCY_GUARD_STORAGE

```solidity
bytes32 private constant REENTRANCY_GUARD_STORAGE = 0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;
```


## Functions
### nonReentrant

*Prevents a contract from calling itself, directly or indirectly.
Calling a `nonReentrant` function from another `nonReentrant`
function is not supported. It is possible to prevent this from happening
by making the `nonReentrant` function external, and making it call a
`private` function that does the actual work.*


```solidity
modifier nonReentrant();
```

### _nonReentrantBefore


```solidity
function _nonReentrantBefore() private;
```

### _nonReentrantAfter


```solidity
function _nonReentrantAfter() private;
```

### _reentrancyGuardEntered

*Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
`nonReentrant` function in the call stack.*


```solidity
function _reentrancyGuardEntered() internal view returns (bool);
```

## Errors
### ReentrancyGuardReentrantCall
*Unauthorized reentrant call.*


```solidity
error ReentrancyGuardReentrantCall();
```


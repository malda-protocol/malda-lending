# IHypernativeFirewall
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/libraries/HypernativeFirewallProtected.sol)


## Functions
### register


```solidity
function register(address account, bool isStrictMode) external;
```

### validateForbiddenAccountInteraction


```solidity
function validateForbiddenAccountInteraction(address sender) external view;
```

### validateForbiddenContextInteraction


```solidity
function validateForbiddenContextInteraction(address origin, address sender) external view;
```

### validateBlacklistedAccountInteraction


```solidity
function validateBlacklistedAccountInteraction(address sender) external;
```


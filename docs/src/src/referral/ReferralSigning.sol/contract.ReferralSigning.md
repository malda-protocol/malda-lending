# ReferralSigning
[Git Source](https://github.com/malda-protocol/malda-lending/blob/413dc9221d099e8e0b7a9a3f94769f4666aaf31b/src\referral\ReferralSigning.sol)


## State Variables
### referredByRegistry

```solidity
mapping(address referredBy => mapping(address user => bool wasReferred)) public referredByRegistry;
```


### referralsForUserRegistry

```solidity
mapping(address user => address referredBy) public referralsForUserRegistry;
```


### referralRegistry

```solidity
mapping(address referredBy => address[] users) public referralRegistry;
```


### totalReferred

```solidity
mapping(address referredBy => uint256 total) public totalReferred;
```


### isUserReferred

```solidity
mapping(address user => bool wasReferred) public isUserReferred;
```


### nonces

```solidity
mapping(address user => uint256 nonce) public nonces;
```


## Functions
### onlyNewUser


```solidity
modifier onlyNewUser();
```

### claimReferral


```solidity
function claimReferral(bytes calldata signature, address referrer) external onlyNewUser;
```

## Events
### ReferralClaimed

```solidity
event ReferralClaimed(address indexed referred, address indexed referrer);
```

### ReferralRejected

```solidity
event ReferralRejected(address indexed referred, address indexed referrer, string reason);
```

## Errors
### ReferralSigning_SameUser

```solidity
error ReferralSigning_SameUser();
```

### ReferralSigning_InvalidSignature

```solidity
error ReferralSigning_InvalidSignature();
```

### ReferralSigning_UserAlreadyReferred

```solidity
error ReferralSigning_UserAlreadyReferred();
```

### ReferralSigning_ContractReferrerNotAllowed

```solidity
error ReferralSigning_ContractReferrerNotAllowed();
```


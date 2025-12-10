# ReferralSigning
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/referral/ReferralSigning.sol)

**Author:**
Malda Protocol

Manages user referrals with signature-based verification


## State Variables
### referredByRegistry
Tracks if a user was referred by a specific referrer


```solidity
mapping(address referredBy => mapping(address user => bool wasReferred)) public referredByRegistry
```


### referralsForUserRegistry
Maps users to their referrer


```solidity
mapping(address user => address referredBy) public referralsForUserRegistry
```


### referralRegistry
Lists all users referred by a referrer


```solidity
mapping(address referredBy => address[] users) public referralRegistry
```


### totalReferred
Total number of users referred by a referrer


```solidity
mapping(address referredBy => uint256 total) public totalReferred
```


### isUserReferred
Tracks if a user has been referred


```solidity
mapping(address user => bool wasReferred) public isUserReferred
```


### nonces
Nonce for each user to prevent replay attacks


```solidity
mapping(address user => uint256 nonce) public nonces
```


## Functions
### onlyNewUser

Modifier to check if the user is a new user


```solidity
modifier onlyNewUser() ;
```

### claimReferral

Claims a referral with signature verification


```solidity
function claimReferral(bytes calldata signature, address referrer) external onlyNewUser;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signature`|`bytes`|User's signature proving consent|
|`referrer`|`address`|Address of the referrer|


## Events
### ReferralClaimed
Emitted when a referral is successfully claimed


```solidity
event ReferralClaimed(address indexed referred, address indexed referrer);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`referred`|`address`|The referred user|
|`referrer`|`address`|The referrer|

### ReferralRejected
Emitted when a referral claim is rejected


```solidity
event ReferralRejected(address indexed referred, address indexed referrer, string reason);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`referred`|`address`|The referred user|
|`referrer`|`address`|The referrer|
|`reason`|`string`|Rejection reason|

## Errors
### ReferralSigning_SameUser
Error thrown when the user is the same as the referrer


```solidity
error ReferralSigning_SameUser();
```

### ReferralSigning_InvalidSignature
Error thrown when the signature is invalid


```solidity
error ReferralSigning_InvalidSignature();
```

### ReferralSigning_UserAlreadyReferred
Error thrown when the user has already been referred


```solidity
error ReferralSigning_UserAlreadyReferred();
```

### ReferralSigning_ContractReferrerNotAllowed
Error thrown when the referrer is a contract


```solidity
error ReferralSigning_ContractReferrerNotAllowed();
```


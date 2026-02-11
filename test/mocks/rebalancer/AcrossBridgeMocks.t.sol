// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

contract MockAcrossSpokePool {
    bytes4 private constant DEPOSIT_V3_NOW_SELECTOR = bytes4(
        keccak256("depositV3Now(address,address,address,address,uint256,uint256,uint256,address,uint32,uint32,bytes)")
    );

    address public lastDepositor;
    address public lastRecipient;
    address public lastInputToken;
    address public lastOutputToken;
    uint256 public lastInputAmount;
    uint256 public lastOutputAmount;
    uint256 public lastDestinationChainId;
    address public lastExclusiveRelayer;
    uint32 public lastFillDeadline;
    uint32 public lastExclusivityDeadline;
    uint256 public lastMessageLength;
    bytes32 public lastMessageWord;

    receive() external payable {}

    fallback() external payable {
        require(msg.sig == DEPOSIT_V3_NOW_SELECTOR, "MockAcrossSpokePool: unknown sel");

        uint256 addressMask = type(uint160).max;
        uint256 uint32Mask = type(uint32).max;
        address depositor;
        address recipient;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 destinationChainId;
        address exclusiveRelayer;
        uint32 fillDeadline;
        uint32 exclusivityDeadline;
        uint256 messageLength;
        bytes32 messageWord;

        assembly {
            depositor := and(calldataload(4), addressMask)
            recipient := and(calldataload(36), addressMask)
            inputToken := and(calldataload(68), addressMask)
            outputToken := and(calldataload(100), addressMask)
            inputAmount := calldataload(132)
            outputAmount := calldataload(164)
            destinationChainId := calldataload(196)
            exclusiveRelayer := and(calldataload(228), addressMask)
            fillDeadline := and(calldataload(260), uint32Mask)
            exclusivityDeadline := and(calldataload(292), uint32Mask)
            let msgOffset := calldataload(324)
            let msgStart := add(4, msgOffset)
            messageLength := calldataload(msgStart)
            messageWord := calldataload(add(msgStart, 32))
        }

        lastDepositor = depositor;
        lastRecipient = recipient;
        lastInputToken = inputToken;
        lastOutputToken = outputToken;
        lastInputAmount = inputAmount;
        lastOutputAmount = outputAmount;
        lastDestinationChainId = destinationChainId;
        lastExclusiveRelayer = exclusiveRelayer;
        lastFillDeadline = fillDeadline;
        lastExclusivityDeadline = exclusivityDeadline;
        lastMessageLength = messageLength;
        lastMessageWord = messageWord;
    }
}

contract MockRebalancer {
    mapping(address market => bool allowed) public whitelisted;

    function setWhitelisted(address market, bool status) external {
        whitelisted[market] = status;
    }

    function isMarketWhitelisted(address market) external view returns (bool) {
        return whitelisted[market];
    }
}

contract MockMarket {
    address public underlying;

    constructor(address _underlying) {
        underlying = _underlying;
    }
}

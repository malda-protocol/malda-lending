// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {
    SendParam,
    MessagingFee,
    ILayerZeroOFT,
    ILayerZeroOFTWrapper,
    OFTLimit,
    OFTReceipt,
    OFTFeeDetail
} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";
import {MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";

contract TestToken is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract MockOFTToken is ERC20, ILayerZeroOFT {
    MessagingFee public lastFee;
    SendParam public lastParams;
    address public lastRefund;
    address public innerToken;

    constructor(string memory name_, string memory symbol_, address innerToken_) ERC20(name_, symbol_) {
        innerToken = innerToken_;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function oftVersion() external pure returns (bytes4 interfaceId, uint64 version) {
        return (bytes4(0), 0);
    }

    function token() external view returns (address) {
        return innerToken;
    }

    function approvalRequired() external pure returns (bool) {
        return false;
    }

    function sharedDecimals() external pure returns (uint8) {
        return 18;
    }

    function quoteOFT(SendParam calldata)
        external
        pure
        returns (OFTLimit memory, OFTFeeDetail[] memory, OFTReceipt memory)
    {
        return (OFTLimit({minAmountLD: 0, maxAmountLD: 0}), new OFTFeeDetail[](0), OFTReceipt(0, 0));
    }

    function quoteSend(SendParam calldata, bool) external pure returns (MessagingFee memory) {
        return MessagingFee({nativeFee: 0, lzTokenFee: 0});
    }

    function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external
        payable
        returns (MessagingReceipt memory receipt, OFTReceipt memory oftReceipt)
    {
        lastParams = _sendParam;
        lastFee = _fee;
        lastRefund = _refundAddress;
        receipt = MessagingReceipt({guid: bytes32("guid"), nonce: 1, fee: _fee});
        oftReceipt = OFTReceipt({amountSentLD: _sendParam.amountLD, amountReceivedLD: _sendParam.amountLD});
    }
}

contract MockWrapperToken is TestToken, ILayerZeroOFTWrapper {
    mapping(address token => bool allowed) public allowed;
    bool public mintOnWithdraw = true;

    constructor(string memory name_, string memory symbol_) TestToken(name_, symbol_) {}

    function setAllowed(address token, bool ok) external {
        allowed[token] = ok;
    }

    function setMintOnWithdraw(bool ok) external {
        mintOnWithdraw = ok;
    }

    function allowedTokens(address token) external view virtual returns (bool) {
        return allowed[token];
    }

    function deposit(address asset, uint256 _amount) external {
        ERC20(asset).transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
    }

    function withdraw(address asset, uint256 _amount) external {
        _burn(msg.sender, _amount);
        if (mintOnWithdraw) {
            MockOFTToken(asset).mint(msg.sender, _amount);
        }
    }
}

contract RevertingWrapperToken is MockWrapperToken {
    constructor() MockWrapperToken("RevertWrapper", "RW") {}

    function allowedTokens(address) external pure override returns (bool) {
        revert("no-oft");
    }
}

contract RevertingOFTToken {
    function token() external pure returns (address) {
        revert("no-oft");
    }
}

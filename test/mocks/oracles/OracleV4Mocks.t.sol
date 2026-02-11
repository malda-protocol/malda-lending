// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

contract MockAdapter {
    uint8 public decimals = 8;
    int256 public price = 1e8;
    uint256 public updatedAt = block.timestamp;

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, price, 0, updatedAt, 0);
    }

    function setPrice(int256 _price) external {
        price = _price;
    }

    function setUpdatedAt(uint256 _time) external {
        updatedAt = _time;
    }
}

contract MockRoles {
    mapping(address account => bool allowed) public allowed;

    function GUARDIAN_ORACLE() external pure returns (bytes32) {
        return keccak256("GUARDIAN_ORACLE");
    }

    function isAllowedFor(address user, bytes32) external view returns (bool) {
        return allowed[user];
    }

    function allow(address user) external {
        allowed[user] = true;
    }
}

contract MockToken {
    string public symbol_ = "MOCK";
    address public underlying_ = address(this);

    function symbol() external view returns (string memory) {
        return symbol_;
    }

    function underlying() external view returns (address) {
        return underlying_;
    }

    function setSymbol(string calldata _symbol) external {
        symbol_ = _symbol;
    }

    function setUnderlying(address _underlying) external {
        underlying_ = _underlying;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    uint8 private _d;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol) {
        _d = _decimals;
    }

    function decimals() public view override returns (uint8) {
        return _d;
    }

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public {
        _burn(_from, _amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@solady/src/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    function name() public pure override returns (string memory) {
        return "DummyCoin";
    }

    function symbol() public pure override returns (string memory) {
        return "COIN";
    }

    function mintTo(address to) public {
        _mint(to, 1_000_000);
    }
}

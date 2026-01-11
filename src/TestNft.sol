// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC721} from "@solady/src/tokens/ERC721.sol";

contract TestNft is ERC721 {
    uint256 private nextTokenId = 1;

    function name() public pure override returns (string memory) {
        return "TestNft";
    }

    function symbol() public pure override returns (string memory) {
        return "TEST";
    }

    function mintTo(address to) public {
        uint256 tokenId = nextTokenId;
        nextTokenId = tokenId + 1;
        _mint(to, tokenId);
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return "";
    }
}

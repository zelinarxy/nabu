// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC721} from "@solady/src/tokens/ERC721.sol";
import {LibString} from "@solady/src/utils/LibString.sol";

contract MockERC721 is ERC721 {
    uint256 private nextTokenId = 1;

    function name() public pure override returns (string memory) {
        return "DummyNft";
    }

    function symbol() public pure override returns (string memory) {
        return "DUMMY";
    }

    function mintTo(address to) public {
        uint256 tokenId = nextTokenId;
        nextTokenId = tokenId + 1;
        _mint(to, tokenId);
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return string.concat("https://foo.bar/", LibString.toString(id));
    }
}

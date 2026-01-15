// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@solady/src/auth/Ownable.sol";
import {ERC721} from "@solady/src/tokens/ERC721.sol";
import {LibString} from "@solady/src/utils/LibString.sol";

/// @dev The token doesn't exist
error NonExistentToken();

/// @title An NFT serving as a whitelist pass for Enkidu minters
///
/// @author Zelinar XY
contract Humbaba is ERC721, Ownable {
    string public baseURI;
    uint256 private nextTokenId = 1;

    constructor(string memory _baseURI) {
        _initializeOwner(msg.sender);
        baseURI = _baseURI;
    }

    function name() public pure override returns (string memory) {
        return "Humbaba";
    }

    function symbol() public pure override returns (string memory) {
        return "HUMB";
    }

    /// @notice Mint an NFT to the specified recipient
    /// @dev Restricted to owner, who should be owner of the corresponding Enkidu deployment
    function adminMintTo(address to) public onlyOwner {
        uint256 tokenId = nextTokenId;
        nextTokenId = tokenId + 1;
        _mint(to, tokenId);
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        if (!_exists(id)) {
            revert NonExistentToken();
        }

        return string.concat(baseURI, LibString.toString(id));
    }

    function updateBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC721} from "lib/solady/src/tokens/ERC721.sol";
import {LibString} from "lib/solady/src/utils/LibString.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

/// @dev The token doesn't exist
error NonExistentToken();

event BaseURIUpdated(string newBaseURI);

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                         𒄷𒌝𒁀𒁀                           */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

/// @title An NFT serving as a whitelist pass for Enkidu minters
///
/// @author Zelinar XY
contract Humbaba is ERC721, Ownable {
    /// @notice The base metadata URI
    string public baseURI;

    uint256 private nextTokenId = 1;

    /// @notice Initialize the contract with a base metadata URI and an owner
    ///
    /// @dev The metadata URI should have a trailing slash, e.g. "ipfs://<hash>/"
    ///
    /// @param _baseURI The base metadata URI
    constructor(string memory _baseURI) {
        _initializeOwner(msg.sender);
        baseURI = _baseURI;
    }

    /// @notice Get the collection name (it's Humbaba)
    function name() public pure override returns (string memory) {
        return "Humbaba";
    }

    /// @notice Get the collection symbol (it's HUMB)
    function symbol() public pure override returns (string memory) {
        return "HUMB";
    }

    /// @notice Mint an NFT to the specified recipient
    ///
    /// @dev Restricted to owner, who should be owner of the corresponding Enkidu deployment
    function adminMintTo(address to) public onlyOwner {
        uint256 tokenId = nextTokenId;
        nextTokenId = tokenId + 1;
        _mint(to, tokenId);
    }

    /// @notice Get the metadata uri for a token
    ///
    /// @param id The token id
    ///
    /// @return uri The uri
    function tokenURI(uint256 id) public view virtual override returns (string memory uri) {
        if (!_exists(id)) {
            revert NonExistentToken();
        }

        uri = string.concat(baseURI, LibString.toString(id));
    }

    /// @notice Update the base metadata URI
    ///
    /// @dev Restricted to the contract owner
    /// @dev Should have a trailing slash, e.g. "ipfs://<hash>/"
    ///
    /// @param newBaseURI The new base URI
    function updateBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }
}

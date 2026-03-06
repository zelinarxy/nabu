// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC721} from "lib/solady/src/tokens/ERC721.sol";
import {LibString} from "lib/solady/src/utils/LibString.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

/// @dev The token doesn't exist
error NonExistentToken();

/// @dev The contract owner has updated the base uri
event BaseUriUpdated(string newBaseUri);

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                         𒄷𒌝𒁀𒁀                           */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

/// @title An NFT serving as a whitelist pass for Enkidu minters
///
/// @author Zelinar XY
contract Humbaba is ERC721, Ownable {
    /// @notice The base metadata uri
    string public baseUri;

    uint256 private nextTokenId = 1;

    /// @notice Initialize the contract with a base metadata uri and an owner
    ///
    /// @dev The metadata uri should have a trailing slash, e.g. "ipfs://<hash>/"
    ///
    /// @param _baseUri The base metadata uri
    constructor(string memory _baseUri) {
        _initializeOwner(msg.sender);
        baseUri = _baseUri;
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
    ///
    /// @param to The recipient address
    function adminMintTo(address to) external onlyOwner {
        uint256 tokenId = nextTokenId;
        unchecked {
            ++nextTokenId;
        }
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

        uri = string.concat(baseUri, LibString.toString(id));
    }

    /// @notice Update the base metadata uri
    ///
    /// @dev Restricted to the contract owner
    /// @dev Requires a trailing slash, e.g. "ipfs://<hash>/"
    ///
    /// @param newBaseUri The new base uri
    function updateBaseUri(string calldata newBaseUri) external onlyOwner {
        baseUri = newBaseUri;
        emit BaseUriUpdated(newBaseUri);
    }
}

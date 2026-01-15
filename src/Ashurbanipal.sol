// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@solady/src/tokens/ERC1155.sol";
import "@solady/src/auth/Ownable.sol";

/// @dev User is unable to send or receive NFTs for a given work because the work's admin has blacklisted them
error IsFrozen();
/// @dev Only the Nabu contract can call the function
error NotNabu();

/// @title NFT passes for writing content to Nabu works
///
/// @author Zelinar XY
contract Ashurbanipal is ERC1155, Ownable {
    /// @notice Address of the Nabu contract
    address private _nabuAddress;

    /// @notice Mapping of ids to metadata uris
    mapping(uint256 => string) private _uris;

    /// @notice A work's admin can ban a user from sending or receiving passes for a work
    /// @dev The first uint256 mapping corresponds to the work id
    mapping(uint256 => mapping(address => bool)) private _freezelist;

    /// @notice Only the Nabu contract can invoke the function
    modifier onlyNabu() {
        require(msg.sender == _nabuAddress, NotNabu());
        _;
    }

    /// @notice Initialize the contract with the Nabu contract address and the owner who can update it
    constructor(address initialNabuAddress) ERC1155() {
        _initializeOwner(msg.sender);
        _nabuAddress = initialNabuAddress;
    }

    /// @notice Mint passes to a newly created work's admin, or an address the admin has specified
    ///
    /// @dev The Nabu contract automatically calls this function when a work is created
    /// @dev Only the Nabu contract can call this function
    ///
    /// @param account The recipient address
    /// @param workId The id of the work, which will serve as the NFT id
    /// @param supply The total number of passes
    /// @param workUri The metadata uri
    function mint(address account, uint256 workId, uint256 supply, string memory workUri) public onlyNabu {
        _mint(account, workId, supply, "");
        _uris[workId] = workUri;
    }

    /// @notice Get the Nabu contract address
    function nabuAddress() public view returns (address) {
        return _nabuAddress;
    }

    /// @notice Freeze or unfreeze a user's passes for a given work
    ///
    /// @dev The Nabu contract automatically calls this function when a work admin invokes `updateBlacklist`
    /// @dev Only the Nabu contract can call this function
    ///
    /// @param workId The id of the work
    /// @param user The address of the user
    /// @param shouldFreeze Should the user's passes be frozen or unfrozen
    function updateFreezelist(uint256 workId, address user, bool shouldFreeze) public onlyNabu {
        _freezelist[workId][user] = shouldFreeze;
    }

    /// @notice Update the Nabu contract address
    ///
    /// @dev Only the contract owner can call this function
    ///
    /// @param newNabuAddress The new address
    function updateNabuAddress(address newNabuAddress) public onlyOwner {
        _nabuAddress = newNabuAddress;
    }

    /// @notice Update the metadata uri for a given work
    ///
    /// @dev Only the Nabu contract can call this function
    ///
    /// @param workId The id of the work
    /// @param newUri The new metadata uri
    function updateUri(uint256 workId, string memory newUri) public onlyNabu {
        _uris[workId] = newUri;
    }

    /// @notice Get a work's metadata uri
    function uri(uint256 workId) public view override returns (string memory) {
        return _uris[workId];
    }

    function _useBeforeTokenTransfer() internal view override returns (bool) {
        return true;
    }

    /// @notice Prevent the transfer of frozen passes
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        uint256 len = ids.length;

        for (uint256 i = 0; i < len; ) {
            uint256 id = ids[i];

            if (_freezelist[id][from] || _freezelist[id][to]) {
                revert IsFrozen();
            }

            unchecked { ++i; }
        }
    }
}

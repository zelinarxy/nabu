// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC1155} from "lib/solady/src/tokens/ERC1155.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                          ERRORS                            */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

/// @dev User is unable to send or receive passes for a given work because the work's admin has blacklisted them
error IsFrozen();
/// @dev Only the Nabu contract can call a given function
error NotNabu();
/// @dev The Nabu contract address cannot be set to address(0)
error ZeroAddress();

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                          EVENTS                            */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

/// @dev A work admin has frozen or unfrozen a user's passes for that work
event FreezelistUpdated(uint256 workId, address user, bool shouldFreeze);

/// @dev The contract owner has updated the Nabu contract address
event NabuAddressUpdated(address newNabuAddress);

/// @dev A work admin has updated the metadata uri for that work
event UriUpdated(uint256 workId, string newUri);

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                         𒀸𒋩𒆕𒀀                           */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

/// @title NFT passes for writing content to Nabu works
///
/// @author Zelinar XY
contract Ashurbanipal is ERC1155, Ownable {
    /// @notice The Nabu contract address
    address private _nabuAddress;

    /// @notice Mapping of work ids to metadata uris
    mapping(uint256 workId => string uri) private _uris;

    /// @notice Track frozen passes: a work admin can ban a given user from sending or receiving passes for that work
    mapping(uint256 workId => mapping(address user => bool isFrozen)) private _freezelist;

    /// @notice The timestamp when a user last received a pass
    ///
    /// @dev Nabu uses these values to enforce a one-day holding period before new pass recipients can participate
    /// @dev This gives work admins time to blacklist bad actors who rotate passes to new addresses after each attack
    /// @dev Receiving additional passes when a user already has a non-zero balance won't update this value
    mapping(uint256 workId => mapping(address user => uint256 receivedAt)) public passReceivedAt;

    /// @notice Only the Nabu contract can invoke the function
    modifier onlyNabu() {
        require(msg.sender == _nabuAddress, NotNabu());
        _;
    }

    /// @notice Initialize the contract with the Nabu contract address and the owner who can update it
    ///
    /// @dev This contract inherits from the Solady implementation of ERC1155
    ///
    /// @param initialNabuAddress The Nabu contract address
    constructor(address initialNabuAddress) ERC1155() {
        _initializeOwner(msg.sender);
        _nabuAddress = initialNabuAddress;
    }

    /// @notice Mint passes to a newly created work's admin, or to an address the admin has specified
    ///
    /// @dev The Nabu contract automatically calls this function when a work is created
    /// @dev Only the Nabu contract can call this function
    /// @dev Nabu work ids correspond to Ashurbanipal NFT ids
    /// @dev Work admins can optionally deploy an Enkidu contract to receive and distribute passes for multiple works
    ///
    /// @param account The address of the passes' recipient
    /// @param workId The id of the work
    /// @param supply The total number of passes
    /// @param workUri The metadata uri
    function mint(address account, uint256 workId, uint256 supply, string calldata workUri) external onlyNabu {
        _mint({to: account, id: workId, amount: supply, data: ""});
        _uris[workId] = workUri;
    }

    /// @notice Get the Nabu contract address
    ///
    /// @return The Nabu contract address
    function getNabuAddress() external view returns (address) {
        return _nabuAddress;
    }

    /// @notice Freeze or unfreeze a user's passes for a given work
    ///
    /// @dev The Nabu contract automatically calls this function when a work admin invokes `updateBlacklist`
    /// @dev Only the Nabu contract can call this function
    /// @dev Nabu work ids correspond to Ashurbanipal NFT ids
    ///
    /// @param workId The id of the work
    /// @param user The address of the user
    /// @param shouldFreeze Whether to freeze or unfreeze the user's passes
    function updateFreezelist(uint256 workId, address user, bool shouldFreeze) external onlyNabu {
        _freezelist[workId][user] = shouldFreeze;
        emit FreezelistUpdated({workId: workId, user: user, shouldFreeze: shouldFreeze});
    }

    /// @notice Update the Nabu contract address
    ///
    /// @dev Only the contract owner can call this function
    ///
    /// @param newNabuAddress The new Nabu contract address
    function updateNabuAddress(address newNabuAddress) external onlyOwner {
        if (newNabuAddress == address(0)) revert ZeroAddress();
        _nabuAddress = newNabuAddress;
        emit NabuAddressUpdated(newNabuAddress);
    }

    /// @notice Update the metadata uri for a given work
    ///
    /// @dev Only the Nabu contract can call this function
    /// @dev Nabu work ids correspond to Ashurbanipal NFT ids
    ///
    /// @param workId The id of the work
    /// @param newUri The new metadata uri
    function updateUri(uint256 workId, string calldata newUri) external onlyNabu {
        _uris[workId] = newUri;
        emit UriUpdated({workId: workId, newUri: newUri});
    }

    /// @notice Get a work's metadata uri
    ///
    /// @dev Nabu work ids correspond to Ashurbanipal NFT ids
    ///
    /// @return The metadata uri
    function uri(uint256 workId) public view override returns (string memory) {
        return _uris[workId];
    }

    function _useBeforeTokenTransfer() internal pure override returns (bool) {
        return true;
    }

    /// @notice Prevent the transfer of passes to or from blacklisted users
    function _beforeTokenTransfer(address from, address to, uint256[] memory ids, uint256[] memory, bytes memory)
        internal
        view
        override
    {
        uint256 len = ids.length;

        for (uint256 i = 0; i < len;) {
            uint256 id = ids[i];

            if (_freezelist[id][from] || _freezelist[id][to]) {
                revert IsFrozen();
            }

            unchecked {
                ++i;
            }
        }
    }

    function _useAfterTokenTransfer() internal pure override returns (bool) {
        return true;
    }

    /// @notice Record when a user's pass balance for a work is replenished from zero via transfer
    ///
    /// @dev This is necessary to enforce a one-day waiting period between receiving a pass and updating work content
    /// @dev Mints (from == address(0)) and users who already had a non-zero balance aren't subject to a waiting period
    function _afterTokenTransfer(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory)
        internal
        override
    {
        if (from == address(0) || to == address(0)) {
            return;
        }

        uint256 len = ids.length;

        for (uint256 i = 0; i < len;) {
            uint256 id = ids[i];

            // balanceOf(to, id) already reflects the post-transfer balance; if it equals the
            // amount just received, the recipient had zero passes before this transfer
            if (balanceOf(to, id) == amounts[i]) {
                passReceivedAt[id][to] = block.timestamp;
            }

            unchecked {
                ++i;
            }
        }
    }
}

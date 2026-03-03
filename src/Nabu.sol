// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibZip} from "lib/solady/src/utils/LibZip.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";
import {SSTORE2} from "lib/solady/src/utils/SSTORE2.sol";
import {Ashurbanipal} from "./Ashurbanipal.sol";

uint256 constant ONE_DAY = 86_400;
uint256 constant SEVEN_DAYS = 604_800;
uint256 constant THIRTY_DAYS = 2_592_000;
uint256 constant MAX_CONTENT_SIZE = 24_576;

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                          ERRORS                            */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

/// @dev User is blacklisted by the work's admin from assigning or confirming passage content for that work
error Blacklisted();
/// @dev A given user is limited to assigning a passage's content or confirming it once
error CannotDoubleConfirmPassage();
/// @dev A user can't assign a passage's metadata if they were the last one to do so
error CannotReassignOwnMetadata();
/// @dev SSTORE2 has a max data size of MAX_CONTENT_SIZE (24_576) bytes
error ContentTooLarge();
/// @dev Works require a title
error EmptyTitle();
/// @dev Passage doesn't exist
error InvalidPassageId();
/// @dev SSTORE2 has a max data size of MAX_CONTENT_SIZE (24_576) bytes
error MetadataTooLarge();
/// @dev Attempting to write the same metadata twice doesn't perform a confirmation; revert to avoid wasting gas
error NoChangeInMetadata();
/// @dev User must hold a "pass" (Ashurbanipal NFT) corresponding to the work in order to assign or confirm content
error NoPass();
/// @dev Passes received via transfer must be held for one day before they can be used; does not apply if the user's balance was already above zero
error PassCooldown(uint256 until);
/// @dev Can't confirm an empty passage
error NoPassageContent();
/// @dev Function is restricted to the work's admin
error NotWorkAdmin(address workAdmin);
/// @dev Can't assign or confirm a passage's content once it's finalized
error PassageAlreadyFinalized();
/// @dev Function can only be called within 30 days of a work's creation
error TooLate(uint256 expiredAt);
/// @dev There is a cooling-off period before first confirmation (one day) and second confirmation (seven days)
error TooSoonToAssignContent(uint256 canAssignAfter);
/// @dev There is a cooling-off period after first confirmation (one day)
error TooSoonToAssignMetadata(uint256 canAssignAfter);
/// @dev There is a seven-day cooling-off period between first and second content confirmations
error TooSoonToConfirmContent(uint256 canConfirmAfter);
/// @dev Work admin address must not be address(0); same with Ashurbanipal address
error ZeroAddress();
/// @dev A work's `totalPassagesCount` must be at least 1
error ZeroPassagesCount();
/// @dev A work's pass supply must be at least 1; a work with no passes can never have content assigned
error ZeroSupply();

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                          EVENTS                            */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

event AshurbanipalUpdated(address newAshurbanipalAddress);

event BlacklistUpdated(uint256 workId, address user, bool shouldBan);

/// @dev Content pointer is the SSTORE2 location, whether new or existing
/// @dev Confirmation index is 0 for freshly assigned/updated content, 1 for the first confirmation, 2 for the second
event PassageContentAssigned(
    uint256 workId, uint256 passageId, address by, address contentPointer, uint8 confirmationIndex
);

/// @dev Content pointer is the SSTORE2 location
event PassageMetadataAssigned(uint256 workId, uint256 passageId, address by, address metadataPointer);

/// @dev Content pointer is the SSTORE2 location, whether new or existing
event PassageContentAssignedByAdmin(uint256 workId, uint256 passageId, address by, address contentPointer);

/// @dev Content pointer is the SSTORE2 location
event PassageMetadataAssignedByAdmin(uint256 workId, uint256 passageId, address by, address metadataPointer);

/// @dev Confirmation index is 1 for the first confirmation (`byOne`), 2 for the second (`byTwo`)
event PassageContentConfirmed(uint256 workId, uint256 passageId, address by, uint8 confirmationIndex);

event WorkAdminUpdated(uint256 workId, address previousAdminAddress, address newAdminAddress);

event WorkAuthorUpdated(uint256 workId, string newAuthor);

event WorkCreated(
    string author,
    string metadata,
    string title,
    uint96 totalPassagesCount,
    string uri,
    uint256 supply,
    address mintTo,
    uint256 id
);

event WorkMetadataUpdated(uint256 workId, string newMetadata);

event WorkTitleUpdated(uint256 workId, string newTitle);

event WorkTotalPassagesCountUpdated(uint256 workId, uint96 newTotalPassagesCount);

event WorkUriUpdated(uint256 workId, string newUri);

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                         STRUCTS                            */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

/**
 * @notice A work is anything that can be expressed in text, but it's easiest to think of it as a book: it must have
 * a title, can have an author, can have arbitrary metadata, and must have a total passages count. When a user creates
 * a work by calling `createWork`, they must specify how many passages the work has (this can be updated, along with
 * author and title, for 30 days after creating the work). This user, who becomes the work's admin, should
 * decide ahead of time what each passage's content should be, and provide other users an interface where they can
 * populate each passage's content correctly. For the Bible, for example, passage 1 would be Genesis 1:1. Works that aren't scripture or classics will need to be broken up into passages by admins.
 */
struct Work {
    /// @dev The real-world author of the work, e.g. Homer or Shakespeare
    string author;
    /// @dev Arbitrary information the work's admin might like to add
    string metadata;
    /// @dev The title of the work, e.g. The Odyssey or Hamlet
    string title;
    /// @dev The metadata URI for the ERC-1155 token id associated with the work (see the Ashurbanipal contract)
    string uri;
    /// @dev The address of the user who initialized the work
    /// @dev The admin can update the work's metadata for a limited amount of time
    /// @dev The admin can overwrite the content of finalized passages indefinitely
    /// @dev To renounce the ability to overwrite content, the admin can update the work's admin to a burn address
    address admin;
    /// @dev The total number of passages in the work
    uint96 totalPassagesCount;
    /// @dev The timestamp at which the work was created (instantiated onchain using Nabu, not written in the real world)
    uint96 createdAt;
}

// TODO
/**
 * @notice Nabu provides a method for preserving texts on EVM blockchains by delegating the task to potentially large
 * networks. The fundamental unit of a text in Nabu is a passage, and the content of a passage is recorded via a three-
 * step process: first, a user assigns content to the empty passage; second, another user (the first user isn't able to
 * perform this step) confirms that the passage's content is correct, either by assigning it identical content or
 * calling a lighter confirm function; third, yet another user (who can't be either of the first two) performs a second
 * confirmation. At this point the passage's content is considered finalized. Only the work's admin (the user who
 * created the work or has been assigned admin status by the creator) can overwrite a passage at this point. Then the
 * confirmation count is reset to zero and the process repeats. The goal is to prevent any given user or group of users
 * from vandalizing a work by assigning it incorrect content, while providing a mechanism for honest users to record
 * their text permanently on the blockchain. Ideally, once every passage of a work is finalized with correct content,
 * the admin renounces their status and the text is set in stone.
 */
struct Passage {
    /// @dev The address pointer for the passage's content
    address content;
    /// @dev The timestamp at which the most recent content assignment or confirmation was performed
    uint96 at;
    /// @dev The address pointer for the passage's metadata
    address metadata;
    /// @dev The timestamp at which the most recent metadata assignment was performed
    uint96 metadataAt;
    /// @dev The address of the user who performed the initial content assignment (possibly an overwrite)
    address byZero;
    /// @dev The address of the user who performed the first content confirmation
    address byOne;
    /// @dev The address of the user who performed the second content confirmation (finalized the passage)
    address byTwo;
    /// @dev The address of the user who performed the most recent metadata assignment
    address metadataBy;
}

struct ReadablePassage {
    /// @dev The decompressed, human readable content
    bytes readableContent;
    /// @dev The decompressed, human readable metadata
    bytes readableMetadata;
    /// @dev The address of the user who performed the initial content assignment (possibly an overwrite)
    address byZero;
    /// @dev The address of the user who performed the first content confirmation
    address byOne;
    /// @dev The address of the user who performed the second content confirmation (finalized the passage)
    address byTwo;
    /// @dev The address of the user who performed the most recent metadata assignment
    address metadataBy;
    /// @dev The timestamp at which the most recent content assignment or confirmation was performed
    uint96 at;
    /// @dev The timestamp at which the most recent metadata assignment was performed
    uint96 metadataAt;
}

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                           𒀭𒀝                            */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

/// @title A text preservation tool
///
/// @author Zelinar XY
contract Nabu is Ownable {
    Ashurbanipal private _ashurbanipal;

    /// @notice A work's admin can ban an address from assigning or confirming passage content for that work
    mapping(uint256 workId => mapping(address user => bool isBlacklisted)) private _blacklist;

    mapping(uint256 workId => mapping(uint256 passageId => Passage)) private _passages;
    mapping(uint256 workId => Work) private _works;

    uint256 private _worksTip;

    /// @notice Only a work's admin can update the work's metadata, e.g. title and author
    modifier onlyWorkAdmin(uint256 workId) {
        address admin = _works[workId].admin;
        if (msg.sender != admin) revert NotWorkAdmin(admin);
        _;
    }

    /// @notice Restricted to the work's admin; must be called within 30 days of the work's creation
    modifier onlyWorkAdminNotTooLate(uint256 workId) {
        Work storage work = _works[workId];
        address admin = work.admin;
        if (msg.sender != admin) revert NotWorkAdmin(admin);
        uint256 expiredAt = work.createdAt + THIRTY_DAYS;
        // Admin can still make changes in the `expiredAt` block itself
        if (block.timestamp > expiredAt) revert TooLate(expiredAt);
        _;
    }

    /// @notice Initialize the contract with an owner: only the owner can update the Ashurbanipal contract address
    constructor() {
        _initializeOwner(msg.sender);
    }

    /// @notice A work's admin can update the content of a passage even if that passage has been finalized
    ///
    /// @dev Unlike other admin-only functions, this one has no time limitation (no `notTooLate` modifier)
    ///
    /// @param workId The id of the work being updated
    /// @param passageId The id of the passage being updated
    /// @param content The content of the passage
    function adminAssignPassageContent(uint256 workId, uint256 passageId, bytes calldata content)
        external
        onlyWorkAdmin(workId)
    {
        if (content.length > MAX_CONTENT_SIZE) {
            revert ContentTooLarge();
        }

        // The passage doesn't exist
        if (passageId == 0 || passageId > _works[workId].totalPassagesCount) {
            revert InvalidPassageId();
        }

        // Compress the content
        bytes memory compressedContent = LibZip.flzCompress(content);

        // Track the address of the SSTORE2 write location for the event
        address contentPointer = SSTORE2.write({data: compressedContent});

        Passage storage passage = _passages[workId][passageId];

        // Assign the content
        passage.content = contentPointer;
        // Mark admin as having performed the initial content assignment
        passage.byZero = msg.sender;
        // Clear the user who performed the first confirmation, if any
        passage.byOne = address(0);
        // Clear the user who performed the second (final) confirmation, if any
        passage.byTwo = address(0);
        // Update the timestamp at which the initial content assignment was performed to the current block
        passage.at = uint96(block.timestamp);

        emit PassageContentAssignedByAdmin({
            workId: workId, passageId: passageId, by: msg.sender, contentPointer: contentPointer
        });
    }

    /// @notice A work's admin can update the metadata of a passage even if that passage has been finalized
    /// @dev Unlike other admin-only functions, this one has no time limitation (no `notTooLate` modifier)
    ///
    /// @param workId The id of the work being updated
    /// @param passageId The id of the passage being updated
    /// @param metadata The metadata of the passage
    function adminAssignPassageMetadata(uint256 workId, uint256 passageId, bytes calldata metadata)
        external
        onlyWorkAdmin(workId)
    {
        if (metadata.length > MAX_CONTENT_SIZE) {
            revert MetadataTooLarge();
        }

        // The passage doesn't exist
        if (passageId == 0 || passageId > _works[workId].totalPassagesCount) {
            revert InvalidPassageId();
        }

        bytes memory compressedMetadata = LibZip.flzCompress(metadata);

        // Track the address of the SSTORE2 write location for the event
        address metadataPointer = SSTORE2.write({data: compressedMetadata});

        Passage storage passage = _passages[workId][passageId];

        passage.metadata = metadataPointer;
        passage.metadataBy = msg.sender;
        passage.metadataAt = uint96(block.timestamp);

        // Clear byTwo so the passage is no longer finalized. This prevents the admin from being able to unilaterally
        // set a passage's metadata in stone (something they can't do for content either)
        passage.byTwo = address(0);

        emit PassageMetadataAssignedByAdmin({
            workId: workId, passageId: passageId, by: msg.sender, metadataPointer: metadataPointer
        });
    }

    /// @notice Anyone holding a work's Ashurbanipal NFT can assign content to a passage
    ///
    /// @dev Once a passage has received two confirmations, only the work's admin can change its content
    /// @dev A user can overwrite a passage's existing content, resetting the confirmation count to zero
    /// @dev If content is identical to the passage's current content, the confirmation count is incremented
    ///
    /// @param workId The id of the work being updated
    /// @param passageId The id of the passage being updated
    /// @param content The content of the passage
    function assignPassageContent(uint256 workId, uint256 passageId, bytes calldata content) external {
        if (content.length > MAX_CONTENT_SIZE) {
            revert ContentTooLarge();
        }

        // If the work doesn't exist, there won't be an NFT "pass" for it, so we forgo that check

        // The passage doesn't exist
        if (passageId == 0 || passageId > _works[workId].totalPassagesCount) {
            revert InvalidPassageId();
        }

        // The user is blacklisted
        if (_blacklist[workId][msg.sender]) {
            revert Blacklisted();
        }

        Passage storage passage = _passages[workId][passageId];

        // The passage has received two confirmations: it's finalized and only the work's admin can update it by
        // explicitly calling `adminAssignPassageContent`
        if (passage.byTwo != address(0)) {
            revert PassageAlreadyFinalized();
        }

        // A user can't confirm passage content they assigned in the first place
        if (passage.byZero == msg.sender || passage.byOne == msg.sender) {
            revert CannotDoubleConfirmPassage();
        }

        // The earliest block in which this function can be successfully called
        uint256 canAssignAfter;

        if (passage.byOne != address(0)) {
            // The waiting period between first confirmation and second confirmation (or overwriting) is seven days
            canAssignAfter = passage.at + SEVEN_DAYS;
        } else if (passage.byZero != address(0)) {
            // The waiting period between initial assignment and first confirmation (or overwriting) is one day
            canAssignAfter = passage.at + ONE_DAY;
        }

        // Not enough time has elapsed
        if (block.timestamp < canAssignAfter) {
            revert TooSoonToAssignContent(canAssignAfter);
        }

        // The user doesn't hold an NFT "pass" from the Ashurbanipal contract corresponding to this work
        if (_ashurbanipal.balanceOf({owner: msg.sender, id: workId}) == 0) {
            revert NoPass();
        }

        // Passes received via transfer must be held for one day before they can be used
        uint256 passReceiveBlock = _ashurbanipal.passReceivedAt(workId, msg.sender);
        if (passReceiveBlock != 0 && block.timestamp < passReceiveBlock + ONE_DAY) {
            revert PassCooldown(passReceiveBlock + ONE_DAY);
        }

        // Track confirmation index for the event: 0 if call is going to be recorded as `byZero` (i.e., a manual
        // confirmation rather than an assignment), 1 if `byOne`, 2 if `byTwo`
        uint8 confirmationIndex;

        // Track the address of the SSTORE2 write location, whether new or existing, for the event
        address contentPointer = passage.content;

        // Compress the content
        bytes memory compressedContent = LibZip.flzCompress(content);

        // The passage already has content assigned to it
        if (contentPointer != address(0)) {
            // The content being assigned is identical to the existing content (perform a confirmation)
            if (keccak256(SSTORE2.read({pointer: contentPointer})) == keccak256(compressedContent)) {
                // The passage already has one confirmation
                if (passage.byOne != address(0)) {
                    // Finalize the passage
                    passage.byTwo = msg.sender;
                    confirmationIndex = 2;
                } else {
                    // Record the first confirmation
                    passage.byOne = msg.sender;
                    confirmationIndex = 1;
                }
            } else {
                // The content being assigned differs from the passage's existing content: overwrite the content,
                // record this user as having performed the initial assignment, and clear the first confirmation (if
                // there had been a second confirmation, the call would already have thrown an error)
                contentPointer = SSTORE2.write({data: compressedContent});
                passage.content = contentPointer;
                passage.byZero = msg.sender;
                passage.byOne = address(0);
                confirmationIndex = 0;
            }
        } else {
            // The passage has not yet been assigned content: write the content and record this user as having
            // performed the initial assignment
            contentPointer = SSTORE2.write({data: compressedContent});
            passage.content = contentPointer;
            passage.byZero = msg.sender;
        }

        // Update the timestamp at which the last content update or confirmation was performed to the current block
        passage.at = uint96(block.timestamp);

        emit PassageContentAssigned({
            workId: workId,
            passageId: passageId,
            by: msg.sender,
            contentPointer: contentPointer,
            confirmationIndex: confirmationIndex
        });
    }

    /// @notice Anyone holding a work's Ashurbanipal NFT can assign arbitrary metadata to a passage
    ///
    /// @dev Metadata is optional: it can be assigned to some passages or none
    /// @dev Once a passage has received two confirmations, only the work's admin can change its metadata
    /// @dev Updating metadata after passage finalization clears the last confirmation (`byTwo`)
    ///
    /// @param workId The id of the work being updated
    /// @param passageId The id of the passage being updated
    /// @param metadata The metadata of the passage
    function assignPassageMetadata(uint256 workId, uint256 passageId, bytes calldata metadata) external {
        if (metadata.length > MAX_CONTENT_SIZE) {
            revert MetadataTooLarge();
        }

        // If the work doesn't exist, there won't be an NFT "pass" for it, so we forgo that check

        // The passage doesn't exist
        if (passageId == 0 || passageId > _works[workId].totalPassagesCount) {
            revert InvalidPassageId();
        }

        // The user is blacklisted
        if (_blacklist[workId][msg.sender]) {
            revert Blacklisted();
        }

        Passage storage passage = _passages[workId][passageId];

        // The passage has received two confirmations: it's finalized and only the work's admin can update it by
        // explicitly calling `adminAssignPassageContent`
        if (passage.byTwo != address(0)) {
            revert PassageAlreadyFinalized();
        }

        if (passage.metadataBy == msg.sender) {
            revert CannotReassignOwnMetadata();
        }

        // The earliest block in which this function can be successfully called
        uint256 canAssignAfter;

        if (passage.metadataBy != address(0)) {
            canAssignAfter = passage.metadataAt + SEVEN_DAYS;
        } else {
            canAssignAfter = passage.metadataAt;
        }

        // Not enough time has elapsed
        if (block.timestamp < canAssignAfter) {
            revert TooSoonToAssignMetadata(canAssignAfter);
        }

        // The user doesn't hold an NFT "pass" from the Ashurbanipal contract corresponding to this work
        if (_ashurbanipal.balanceOf({owner: msg.sender, id: workId}) == 0) {
            revert NoPass();
        }

        // Passes received via transfer must be held for one day before they can be used
        uint256 passReceiveBlock = _ashurbanipal.passReceivedAt(workId, msg.sender);
        if (passReceiveBlock != 0 && block.timestamp < passReceiveBlock + ONE_DAY) {
            revert PassCooldown(passReceiveBlock + ONE_DAY);
        }

        // Track the address of the SSTORE2 write location, whether new or existing, for the event
        address metadataPointer = passage.metadata;

        // Compress the content
        bytes memory compressedMetadata = LibZip.flzCompress(metadata);

        if (metadataPointer != address(0)) {
            if (keccak256(SSTORE2.read({pointer: metadataPointer})) == keccak256(compressedMetadata)) {
                revert NoChangeInMetadata();
            }
        }

        metadataPointer = SSTORE2.write({data: compressedMetadata});
        passage.metadata = metadataPointer;
        passage.metadataBy = msg.sender;
        passage.metadataAt = uint96(block.timestamp);

        emit PassageMetadataAssigned({
            workId: workId, passageId: passageId, by: msg.sender, metadataPointer: metadataPointer
        });
    }

    /// @notice Anyone holding a work's Ashurbanipal NFT can confirm a passage's existing content
    ///
    /// @dev Two confirmations finalizes a passage's content; at that point only the work's admin can change it
    /// @dev The passage must already have assigned content (can't point to address(0)) or the call throws an error
    ///
    /// @param workId The id of the work being updated
    /// @param passageId The id of the passage being updated
    function confirmPassageContent(uint256 workId, uint256 passageId) external {
        // If the work doesn't exist, there won't be an NFT "pass" for it, so we forgo that check

        // The passage doesn't exist
        if (passageId == 0 || passageId > _works[workId].totalPassagesCount) {
            revert InvalidPassageId();
        }

        // The user is blacklisted
        if (_blacklist[workId][msg.sender]) {
            revert Blacklisted();
        }

        Passage storage passage = _passages[workId][passageId];

        // Can't confirm a passage with no assigned content
        if (passage.content == address(0)) {
            revert NoPassageContent();
        }

        // The passage already has two confirmations (is finalized)
        if (passage.byTwo != address(0)) {
            revert PassageAlreadyFinalized();
        }

        // The same user can't assign and confirm a passage's content
        if (passage.byZero == msg.sender || passage.byOne == msg.sender) {
            revert CannotDoubleConfirmPassage();
        }

        // The earliest block in which this function can be successfully called
        uint256 canConfirmAfter;

        if (passage.byOne != address(0)) {
            // The waiting period between first confirmation and second confirmation is seven days
            canConfirmAfter = passage.at + SEVEN_DAYS;
        } else {
            // The waiting period between initial assignment and first confirmation is one day
            canConfirmAfter = passage.at + ONE_DAY;
        }

        // Not enough time has elapsed
        if (block.timestamp < canConfirmAfter) {
            revert TooSoonToConfirmContent(canConfirmAfter);
        }

        // The user doesn't hold an NFT "pass" from the Ashurbanipal contract corresponding to this work
        if (_ashurbanipal.balanceOf({owner: msg.sender, id: workId}) == 0) {
            revert NoPass();
        }

        // Passes received via transfer must be held for one day before they can be used
        uint256 passReceiveBlock = _ashurbanipal.passReceivedAt(workId, msg.sender);
        if (passReceiveBlock != 0 && block.timestamp < passReceiveBlock + ONE_DAY) {
            revert PassCooldown(passReceiveBlock + ONE_DAY);
        }

        // Track confirmation index for the event: 1 if caller is going to be recorded as `byOne`, 2 if `byTwo`
        uint8 confirmationIndex = 1;

        if (passage.byOne != address(0)) {
            // Record this user as having performed the second (final) confirmation
            passage.byTwo = msg.sender;
            confirmationIndex = 2;
        } else {
            // Record this user as having performed the first confirmation
            passage.byOne = msg.sender;
        }

        // Update the timestamp at which the last content confirmation was performed to the current block
        passage.at = uint96(block.timestamp);

        emit PassageContentConfirmed({
            workId: workId, passageId: passageId, by: msg.sender, confirmationIndex: confirmationIndex
        });
    }

    /// @notice Create and configure a new work; the user who calls this function becomes the work's admin
    ///
    /// @dev Absent `mintTo`, admin receives "pass" NFTs from the Ashurbanipal contract (count is equal to `supply`)
    ///
    /// @param author The real-world author of the work, e.g. Homer or Shakespeare
    /// @param metadata Arbitrary information the work's admin might like to add
    /// @param title The title of the work, e.g. The Odyssey or Hamlet
    /// @param totalPassagesCount The total number of passages in the work
    /// @param uri The metadata uri for the ERC-1155 token id associated with the work (see the Ashurbanipal contract)
    /// @param supply The total supply of "pass" NFTs the Ashurbanipal contract will mint for distribution (see mintTo)
    /// @param mintTo The address the "pass" NFTs should be minted to (optional, falls back to msg.sender)
    ///
    /// @return newWorksTip The updated works tip
    function createWork(
        string memory author,
        string memory metadata,
        string memory title,
        uint96 totalPassagesCount,
        string memory uri,
        uint256 supply,
        address mintTo
    ) external returns (uint256 newWorksTip) {
        if (totalPassagesCount == 0) {
            revert ZeroPassagesCount();
        }

        if (supply == 0) {
            revert ZeroSupply();
        }

        if (bytes(title).length == 0) {
            revert EmptyTitle();
        }

        address mintToOrAdmin = mintTo;
        if (mintToOrAdmin == address(0)) {
            mintToOrAdmin = msg.sender;
        }

        uint256 workId;
        unchecked {
            workId = ++_worksTip;
        }

        _works[workId] = Work({
            author: author,
            metadata: metadata,
            title: title,
            uri: uri,
            admin: msg.sender,
            totalPassagesCount: totalPassagesCount,
            createdAt: uint96(block.timestamp)
        });

        // Mint a quantity (specified by the `supply` parameter) of Ashurbanipal ERC-1155 NFTs to mintTo (which falls
        // back to msg.sender, the work's admin). This recipient is responsible for distributing the NFTs, which serve
        // as "passes" allowing holders to assign or confirm the content of passages in the corresponding work
        _ashurbanipal.mint({account: mintToOrAdmin, workId: workId, supply: supply, workUri: uri});
        newWorksTip = workId;

        emit WorkCreated({
            author: author,
            metadata: metadata,
            title: title,
            totalPassagesCount: totalPassagesCount,
            uri: uri,
            supply: supply,
            mintTo: mintToOrAdmin,
            id: workId
        });
    }

    /// @notice Get the Ashurbanipal contract address
    ///
    /// @return The Ashurbanipal contract address
    function getAshurbanipalAddress() external view returns (address) {
        return address(_ashurbanipal);
    }

    /// @notice Update the Ashurbanipal contract
    ///
    /// @dev Restricted to the Nabu contract owner
    ///
    /// @param newAshurbanipalAddress The new Ashurbanipal contract address
    function updateAshurbanipal(address newAshurbanipalAddress) external onlyOwner {
        if (newAshurbanipalAddress == address(0)) {
            revert ZeroAddress();
        }

        _ashurbanipal = Ashurbanipal(newAshurbanipalAddress);
        emit AshurbanipalUpdated(newAshurbanipalAddress);
    }

    /// @notice Update the blacklist for a work, either banning or un-banning an address
    ///
    /// @dev Blacklisting also freezes users' Ashurbanipal "pass" NFTs: the user can neither send nor receive a pass
    /// @dev Restricted to the work's current admin
    ///
    /// @param workId The id of the work
    /// @param user The address of the user to be updated
    /// @param shouldBan Should the user be banned or unbanned
    function updateBlacklist(uint256 workId, address user, bool shouldBan) external onlyWorkAdmin(workId) {
        _blacklist[workId][user] = shouldBan;

        // Freeze the user's Ashurbanipal "pass" NFTs to prevent transfer to a sybil (or unfreeze)
        _ashurbanipal.updateFreezelist({workId: workId, user: user, shouldFreeze: shouldBan});

        emit BlacklistUpdated({workId: workId, user: user, shouldBan: shouldBan});
    }

    /// @notice Update the admin address for a work
    ///
    /// @dev Restricted to the work's current admin
    /// @dev A work's admin can renounce their status by calling this function with a burn address (e.g. 0x0...dEaD)
    ///
    /// @param workId The id of the work
    /// @param newAdminAddress The address of the work's new admin
    function updateWorkAdmin(uint256 workId, address newAdminAddress) external onlyWorkAdmin(workId) {
        if (newAdminAddress == address(0)) {
            revert ZeroAddress();
        }

        address previousAdminAddress = _works[workId].admin;
        _works[workId].admin = newAdminAddress;
        emit WorkAdminUpdated({
            workId: workId, previousAdminAddress: previousAdminAddress, newAdminAddress: newAdminAddress
        });
    }

    /// @notice Update the author of a work
    ///
    /// @dev Restricted to the work's admin; must be called within 30 days of the work's creation
    ///
    /// @param workId The id of the work
    /// @param newAuthor The work's new author (the real-world author, e.g. Homer or Shakespeare)
    function updateWorkAuthor(uint256 workId, string calldata newAuthor) external onlyWorkAdminNotTooLate(workId) {
        _works[workId].author = newAuthor;
        emit WorkAuthorUpdated({workId: workId, newAuthor: newAuthor});
    }

    /// @notice Update the metadata of a work
    ///
    /// @dev Restricted to the work's admin; must be called within 30 days of the work's creation
    ///
    /// @param workId The id of the work
    /// @param newMetadata The work's new metadata (an arbitrary string: whatever the admin wants)
    function updateWorkMetadata(uint256 workId, string calldata newMetadata) external onlyWorkAdminNotTooLate(workId) {
        _works[workId].metadata = newMetadata;
        emit WorkMetadataUpdated({workId: workId, newMetadata: newMetadata});
    }

    /// @notice Update the title of a work
    ///
    /// @dev Restricted to the work's admin; must be called within 30 days of the work's creation
    ///
    /// @param workId The id of the work
    /// @param newTitle The work's new title, e.g. The Odyssey or Hamlet
    function updateWorkTitle(uint256 workId, string calldata newTitle) external onlyWorkAdminNotTooLate(workId) {
        if (bytes(newTitle).length == 0) {
            revert EmptyTitle();
        }

        _works[workId].title = newTitle;
        emit WorkTitleUpdated({workId: workId, newTitle: newTitle});
    }

    /// @notice Update the total number of passages in a work
    ///
    /// @dev Restricted to the work's admin; must be called within 30 days of the work's creation
    /// @dev When creating a work, it's necessary to break it into a set number of passages ahead of time
    ///
    /// @param workId The id of the work
    /// @param newTotalPassagesCount The work's new total passage count: must be at least 1
    function updateWorkTotalPassagesCount(uint256 workId, uint96 newTotalPassagesCount)
        external
        onlyWorkAdminNotTooLate(workId)
    {
        if (newTotalPassagesCount == 0) {
            revert ZeroPassagesCount();
        }

        _works[workId].totalPassagesCount = newTotalPassagesCount;
        emit WorkTotalPassagesCountUpdated({workId: workId, newTotalPassagesCount: newTotalPassagesCount});
    }

    /// @notice Update the metadata URI of the ERC-1155 id associated with the work
    ///
    /// @dev Restricted to the work's admin; no time restriction
    /// @dev See the Ashurbanipal contract, which defines NFT "passes" that grant permission to assign a work's content
    ///
    /// @param workId The id of the work
    /// @param newUri The work's new metadata URI
    function updateWorkUri(uint256 workId, string calldata newUri) external onlyWorkAdmin(workId) {
        _ashurbanipal.updateUri({workId: workId, newUri: newUri});
        _works[workId].uri = newUri;
        emit WorkUriUpdated({workId: workId, newUri: newUri});
    }

    /// @notice View a passage: decompressed content and confirmation metadata
    ///
    /// @param workId The id of the work
    /// @param passageId The id of the passage
    ///
    /// @return readablePassage The passage
    function getPassage(uint256 workId, uint256 passageId)
        external
        view
        returns (ReadablePassage memory readablePassage)
    {
        // The passage doesn't exist
        if (passageId == 0 || passageId > _works[workId].totalPassagesCount) {
            revert InvalidPassageId();
        }

        Passage memory passage = _passages[workId][passageId];

        bytes memory readableContent;
        bytes memory readableMetadata;

        if (passage.content != address(0)) {
            bytes memory compressedContent = SSTORE2.read({pointer: passage.content});
            readableContent = LibZip.flzDecompress(compressedContent);
        }

        if (passage.metadata != address(0)) {
            bytes memory compressedMetadata = SSTORE2.read({pointer: passage.metadata});
            readableMetadata = LibZip.flzDecompress(compressedMetadata);
        }

        readablePassage = ReadablePassage({
            readableContent: readableContent,
            readableMetadata: readableMetadata,
            byZero: passage.byZero,
            byOne: passage.byOne,
            byTwo: passage.byTwo,
            metadataBy: passage.metadataBy,
            at: passage.at,
            metadataAt: passage.metadataAt
        });
    }

    /// @notice View a work: author, title, admin, etc. (but no content)
    ///
    /// @param workId The id of the work
    ///
    /// @return The work
    function getWork(uint256 workId) external view returns (Work memory) {
        return _works[workId];
    }

    /// @notice Check whether a user is banned from writing or confirming passages in a certain work
    ///
    /// @param workId The id of the work
    /// @param user The address of the user
    ///
    /// @return The user's blacklist status
    function getIsBlacklisted(uint256 workId, address user) external view returns (bool) {
        return _blacklist[workId][user];
    }
}

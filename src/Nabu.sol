// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@solady/src/auth/Ownable.sol";
import {SSTORE2} from "@solady/src/utils/SSTORE2.sol";
import "./Ashurbanipal.sol";

uint256 constant ONE_DAY = 7_200;
uint256 constant SEVEN_DAYS = 50_400;
uint256 constant THIRTY_DAYS = 216_000;

/// @dev User is blacklisted by the work's admin from assigning or confirming passage content for that work
error Blacklisted();
/// @dev A given user is limited to assigning a passage's content or confirming it once
error CannotDoubleConfirmPassage();
/// @dev SSTORE2 has a max length of 24576
error ContentTooLarge();
/// @dev Passage doesn't exist
error InvalidPassageId();
/// @dev User must hold a "pass" (Ashurbanipal NFT) corresponding to the work in order to assign or confirm content
error NoPass();
/// @dev No confirming an empty passage
error NoPassageContent();
/// @dev Function is restricted to the work's admin
error NotWorkAdmin(address workAdmin);
/// @dev Can't assign or confirm a passage's content if it's already finalized
error PassageAlreadyFinalized();
/// @dev Function can only be called within 30 days of a work's creation
error TooLate(uint256 expiredAt);
/// @dev There is a one-day cooling-off period between initial content assignment and first confirmation
error TooSoonToAssignContent(uint256 canAssignAfter);
/// @dev There is a seven-day cooling-off period between first and second content confirmations
error TooSoonToConfirmContent(uint256 canConfirmAfter);

/**
 * @notice A work can be anything that can be expressed in text, but it's easiest to think of it as a book: it should
 * have a title, can have an author, can have arbitrary metadata, and must have a total passages count. When a user
 * creates a work by calling `createWork`, they must specify how many passages the work has (this can be updated, along
 * with author, title and metadata, for 30 days after creating the work). This user, who becomes the work's admin,
 * should specify ahead of time what each passage's content should be, and provide other users an interface where they
 * can populate each passage's content correctly. For the Bible, for example, passage 0 would probably be Genesis 1:1,
 * compressed to save gas. Works that aren't scripture or classics will need to be broken up into passages by admins.
 */
struct Work {
    /// @dev The real-world author of the work, e.g. Shakespeare
    string author;
    /// @dev Arbitrary information the work's admin might like to add
    string metadata;
    /// @dev The title of the work, e.g. The Odyssey
    string title;
    /// @dev The address of the user who initialized the work
    /// @dev The admin can update the work's metadata for a limited amount of time
    /// @dev The admin can overwrite the content of finalized passages indefinitely
    /// @dev To renounce the ability to overwrite content, the admin can update the work's admin to a burn address
    address admin;
    /// @dev The total number of passages in the work
    uint256 totalPassagesCount;
    /// @dev The block at which the work was created
    uint256 createdAt;
    /// @dev The metadata URI for the ERC-1155 token id associated with the work (see the Ashurbanipal contract)
    string uri;
}

/**
 * @notice Nabu provides a method for preserving texts on EVM blockchains by delegating the task to potentially large
 * networks. The fundamental unit of a text in Nabu is a passage, and the content of a passage is recorded via a three-
 * step process: first, a user assigns content to the empty passage; second, another user (the first user isn't able to
 * perform this step) confirms that the passage's content is correct, either by assigning it identical content or
 * calling a lighter confirm function; third, a third user (can't be either of the first two) performs a second
 * confirmation. At this point the passage's content is considered finalized. Only the work's admin (the user who
 * created the work or was assigned admin status by the creator) can overwrite a passage at this point. Then the
 * confirmation count is reset to zero and the process repeats. The goal is to prevent any given user or group of users
 * from vandalizing a work by assigning it incorret content, while providing a mechanism for honest users to record
 * their text permanently on the blockchain. Ideally, once every passage of a work is finalized with correct content,
 * the admin renounces their status and the text is set in stone.
 */
struct Passage {
    /// @dev The address pointer for the passage's content, which should be compressed to save gas
    /// @dev Nothing necessarily dictates a particular compression algorithm, but Nabut has been tested with FastLZ
    /// @dev See: https://github.com/ariya/FastLZ
    address content;
    /// @dev The address of the user who performed the initial content assignment (possibly an overwrite)
    address byZero;
    /// @dev The address of the user who performed the first content confirmation
    address byOne;
    /// @dev The address of the user who performed the second content confirmation (finalized the passage)
    address byTwo;
    /// @dev The block at which the last content assignment or confirmation was performed
    uint256 at;
}

/// @title A text preservation tool
///
/// @author Zelinar XY
contract Nabu is Ownable {
    Ashurbanipal private _ashurbanipal;

    /// @notice Address of the contract used to mint NFTs granting permission to write or confirm works' content
    address public ashurbanipalAddress;

    /// @notice A work's admin can ban an address from assigning or confirming passage content for that work
    /// @dev The first uint256 mapping corresponds to the work id
    mapping(uint256 => mapping(address => bool)) private _blacklist;

    /// @dev The first uint256 mapping corresponds to the work id
    mapping(uint256 => mapping(uint256 => Passage)) private _passages;

    mapping(uint256 => Work) private _works;
    uint256 private _worksTip;

    /// @notice A work's admin has 30 days to make updates to the work's title, author, etc.
    modifier notTooLate(uint256 workId) {
        uint256 expiredAt = _works[workId].createdAt + THIRTY_DAYS;
        // admin can still make changes in the `expiredAt` block itself
        require(block.number < expiredAt + 1, TooLate(expiredAt));
        _;
    }

    /// @notice Only a work's admin can update the work's metadata, e.g. title and author
    modifier onlyWorkAdmin(uint256 workId) {
        address admin = _works[workId].admin;
        require(msg.sender == admin, NotWorkAdmin(admin));
        _;
    }

    /// @notice Initialize the contract with owner: only the owner can update the Ashurbanipal contract address
    constructor() {
        _initializeOwner(msg.sender);
    }

    /// @notice A work's admin can update the content of a passage even if that passage has been finalized
    /// @notice Unlike other admin-only functions, this one has no time limitation (`notTooLate` modifier)
    ///
    /// @dev Content should be compressed to save gas; the contract has been tested with FastLZ compression
    ///
    /// @param workId The id of the work being updated
    /// @param passageId The id of the passage being updated
    /// @param content The content of the passage
    function adminAssignPassageContent(uint256 workId, uint256 passageId, bytes memory content)
        public
        onlyWorkAdmin(workId)
    {
        // SSTORE2 max size
        if (content.length > 24576) {
            revert ContentTooLarge();
        }

        Work storage work = _works[workId];

        // The passage doesn't exist
        if (passageId > work.totalPassagesCount) {
            revert InvalidPassageId();
        }

        // Assign the content
        _passages[workId][passageId].content = SSTORE2.write(content);
        // Mark admin as having performed the initial content assignment
        _passages[workId][passageId].byZero = msg.sender;
        // Clear the user who performed the first confirmation, if any
        _passages[workId][passageId].byOne = address(0);
        // Clear the user who performed the second (final) confirmation, if any
        _passages[workId][passageId].byTwo = address(0);
        // Update the block number at which the initial content assignment was performed to the current block
        _passages[workId][passageId].at = block.number;
    }

    /// @notice Anyone holding a work's Ashurbanipal NFT can assign content to a passage
    /// @notice Once a passage has received two confirmations, only the work's admin can change its content
    /// @notice A user can overwrite a passage's existing content, resetting the confirmation count to zero
    /// @notice If content is identical to the passage's current content, the confirmation count is incremented
    ///
    /// @dev Content should be compressed to save gas; the contract has been tested with FastLZ compression
    ///
    /// @param workId The id of the work being updated
    /// @param passageId The id of the passage being updated
    /// @param content The content of the passage
    function assignPassageContent(uint256 workId, uint256 passageId, bytes memory content) public {
        // SSTORE2 max size
        if (content.length > 24576) {
            revert ContentTooLarge();
        }

        Work storage work = _works[workId];

        // The passage doesn't exist
        if (passageId > work.totalPassagesCount) {
            revert InvalidPassageId();
        }

        // The user is blacklisted
        if (_blacklist[workId][msg.sender]) {
            revert Blacklisted();
        }

        Passage memory passage = _passages[workId][passageId];

        // The passage has received two confirmations: it's finalized and only the work's admin can update it
        if (passage.byTwo != address(0)) {
            revert PassageAlreadyFinalized();
        }

        // A user can't confirm passage content they assigned in the first place; nor can they double-confirm
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
        if (block.number < canAssignAfter) {
            revert TooSoonToAssignContent(canAssignAfter);
        }

        // The user doesn't hold an NFT "pass" from the Ashurbanipal contract corresponding to this work
        if (_ashurbanipal.balanceOf(msg.sender, workId) == 0) {
            revert NoPass();
        }

        // The passage already has content assigned to it
        if (passage.content != address(0)) {
            // The content being assigned is identical to the existing content (perform a confirmation)
            if (keccak256(SSTORE2.read(passage.content)) == keccak256(content)) {
                // The passage already has one confirmation
                if (passage.byOne != address(0)) {
                    // Finalize the passage
                    _passages[workId][passageId].byTwo = msg.sender;
                } else {
                    // Record the first confirmation
                    _passages[workId][passageId].byOne = msg.sender;
                }
            } else {
                // The content being assigned differs from the passage's existing content: overwrite the content,
                // record this user as having performed the intial assignment, and clear the first confirmation (if
                // there had been a second confirmation, the call would already have thrown an error)
                _passages[workId][passageId].content = SSTORE2.write(content);
                _passages[workId][passageId].byZero = msg.sender;
                _passages[workId][passageId].byOne = address(0);
            }
        } else {
            // The passage has not yet been assigned content: write the content and record this user as having
            // performed the initial assignement
            _passages[workId][passageId].content = SSTORE2.write(content);
            _passages[workId][passageId].byZero = msg.sender;
        }

        // Update the block number at which the last content update or confirmation was performed to the current block
        _passages[workId][passageId].at = block.number;
    }

    /// @notice Anyone holding a work's Ashurbanipal NFT can confirm a passage's existing content
    /// @notice Two confirmations finalizes a passage's content; at that point only the work's admin can change it
    /// @notice The passage must have assigned content (can't point to address(0)) or the call throws an error
    ///
    /// @param workId The id of the work being updated
    /// @param passageId The id of the passage being updated
    function confirmPassageContent(uint256 workId, uint256 passageId) public {
        Work storage work = _works[workId];

        // The passage doesn't exist
        if (passageId > work.totalPassagesCount) {
            revert InvalidPassageId();
        }

        // The user is blacklisted
        if (_blacklist[workId][msg.sender]) {
            revert Blacklisted();
        }

        Passage memory passage = _passages[workId][passageId];

        // Can't confirm a passage with no assigned content
        if (passage.content == address(0)) {
            revert NoPassageContent();
        }

        // The passage already has two confirmations (is finalized)
        if (passage.byTwo != address(0)) {
            revert PassageAlreadyFinalized();
        }

        // The same user can't assign and confirm a passage's content; nor can they double-confirm
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
        if (block.number < canConfirmAfter) {
            revert TooSoonToConfirmContent(canConfirmAfter);
        }

        // The user doesn't hold an NFT "pass" from the Ashurbanipal contract corresponding to this work
        if (_ashurbanipal.balanceOf(msg.sender, workId) == 0) {
            revert NoPass();
        }

        if (passage.byOne != address(0)) {
            // Record this user as having performed the second (final) confirmation
            _passages[workId][passageId].byTwo = msg.sender;
        } else {
            // Record this user as having performed the first confirmation
            _passages[workId][passageId].byOne = msg.sender;
        }

        // Update the block number at which the last content confirmation was performed to the current block
        _passages[workId][passageId].at = block.number;
    }

    /// @notice Create and configure a new work; the user who calls this function becomes the work's admin
    /// @notice Admin receives the number of "pass" NFTs from the Ashurbanipal contract specified by the supply arg
    ///
    /// @param author The real-world author of the work, e.g. Shakespeare
    /// @param metadata Arbitrary information the work's admin might like to add
    /// @param title The title of the work, e.g. The Odyssey
    /// @param totalPassagesCount The total number of passages in the work
    /// @param uri The metadata uri for the ERC-1155 token id associated with the work (see the Ashurbanipal contract)
    /// @param supply The total supply of "pass" NFTs the Ashurbanipal contract will mint to the admin for distribution
    ///
    /// @return newWorksTip The updated works tip
    function createWork(
        string memory author,
        string memory metadata,
        string memory title,
        uint256 totalPassagesCount,
        string memory uri,
        uint256 supply
    ) public returns (uint256 newWorksTip) {
        _worksTip += 1;
        _works[_worksTip] = Work(author, metadata, title, msg.sender, totalPassagesCount, block.number, uri);

        // Mint a quantity (specified by the `supply` parameter) of Ashurbanipal ERC-1155 NFTs to admin, who is
        // responsible for distributing them. These NFTs serve as "passes," allowing holders to assign or confirm the
        // content of passages in the corresponding work
        _ashurbanipal.mint(msg.sender, _worksTip, supply, uri);
        newWorksTip = _worksTip;
    }

    /// @notice Update the Ashurbanipal contract
    /// @notice Restricted to the Nabu contract owner
    ///
    /// @param newAshurbanipalAddress The new Ashurbanipal contract address
    function updateAshurbanipalAddress(address newAshurbanipalAddress) public onlyOwner {
        ashurbanipalAddress = newAshurbanipalAddress;
        _ashurbanipal = Ashurbanipal(newAshurbanipalAddress);
    }

    /// @notice Update the blacklist for a work, either banning or un-banning an address
    /// @notice Blacklisting also freezes users' Ashurbanipal "pass" NFTs: the user can neither send nor receive a pass
    /// @notice Restricted to the work's current admin
    ///
    /// @param workId The id of the work
    /// @param user The address of the user to be updated
    /// @param shouldBan Should the user be banned or unbanned
    function updateBlacklist(uint256 workId, address user, bool shouldBan) public onlyWorkAdmin(workId) {
        _blacklist[workId][user] = shouldBan;

        // Freeze the user's Ashurbanipal "pass" NFTs to prevent transfer to a sybil (or unfreeze)
        _ashurbanipal.updateFreezelist(workId, user, shouldBan);
    }

    /// @notice Update the admin address for a work
    /// @notice Restricted to the work's current admin
    /// @notice A work's admin can renounce their status by calling this function with a burn address (e.g. 0x0...dEaD)
    ///
    /// @param workId The id of the work
    /// @param newAdminAddress The address of the work's new admin
    function updateWorkAdmin(uint256 workId, address newAdminAddress) public onlyWorkAdmin(workId) {
        _works[workId].admin = newAdminAddress;
    }

    /// @notice Update the author of a work
    /// @notice Restricted to the work's admin; must be called within 30 days of the work's creation
    ///
    /// @param workId The id of the work
    /// @param newAuthor The work's new author (the real-world author, e.g. Shakespeare)
    function updateWorkAuthor(uint256 workId, string memory newAuthor)
        public
        notTooLate(workId)
        onlyWorkAdmin(workId)
    {
        _works[workId].author = newAuthor;
    }

    /// @notice Update the metadata of a work
    /// @notice Restricted to the work's admin; must be called within 30 days of the work's creation
    ///
    /// @param workId The id of the work
    /// @param newMetadata The work's new metadata (an arbitrary string: whatever the admin wants)
    function updateWorkMetadata(uint256 workId, string memory newMetadata)
        public
        notTooLate(workId)
        onlyWorkAdmin(workId)
    {
        _works[workId].metadata = newMetadata;
    }

    /// @notice Update the title of a work
    /// @notice Restricted to the work's admin; must be called within 30 days of the work's creation
    ///
    /// @param workId The id of the work
    /// @param newTitle The work's new title (e.g. The Odyssey)
    function updateWorkTitle(uint256 workId, string memory newTitle) public notTooLate(workId) onlyWorkAdmin(workId) {
        _works[workId].title = newTitle;
    }

    /// @notice Update the total number of passages in a work
    /// @notice Restricted to the work's admin; must be called within 30 days of the work's creation
    ///
    /// @dev When creating a work, it's necessary to break it into a set number of passages ahead of time
    ///
    /// @param workId The id of the work
    /// @param newTotalPassagesCount The work's new total passage count
    function updateWorkTotalPassagesCount(uint256 workId, uint256 newTotalPassagesCount)
        public
        notTooLate(workId)
        onlyWorkAdmin(workId)
    {
        _works[workId].totalPassagesCount = newTotalPassagesCount;
    }

    /// @notice Update the metadata URI of the ERC-1155 id associated with the work
    /// @notice Restricted to the work's admin; must be called within 30 days of the work's creation
    ///
    /// @dev See the Ashurbanipal contract, which defines NFT "passes" that grant permission to assign a work's content
    ///
    /// @param workId The id of the work
    /// @param newUri The work's new metadata URI
    function updateWorkUri(uint256 workId, string memory newUri) public notTooLate(workId) onlyWorkAdmin(workId) {
        _ashurbanipal.updateUri(workId, newUri);
        _works[workId].uri = newUri;
    }

    /// @notice View a passage: content and confirmation metadata
    ///
    /// @dev Conent is returned as written; if compressed (recommended) the consuming application needs to decompress
    ///
    /// @param workId The id of the work
    /// @param passageId The id of the passage
    ///
    /// @return passage The passage
    function getPassage(uint256 workId, uint256 passageId) public view returns (Passage memory passage) {
        passage = _passages[workId][passageId];
    }

    /// @notice View a passage's content only
    ///
    /// @dev Conent is returned as written; if compressed (recommended) the consuming application needs to decompress
    ///
    /// @param workId The id of the work
    /// @param passageId The id of the passage
    ///
    /// @return passageContent The passage's content
    function getPassageContent(uint256 workId, uint256 passageId) public view returns (bytes memory passageContent) {
        passageContent = SSTORE2.read(_passages[workId][passageId].content);
    }

    /// @notice View a work: author, title, admin, etc. (but no content)
    ///
    /// @param workId The id of the work
    ///
    /// @return work The work
    function getWork(uint256 workId) public view returns (Work memory work) {
        work = _works[workId];
    }

    function getIsBlacklisted(uint256 workId, address user) public view returns (bool isBlacklisted) {
        isBlacklisted = _blacklist[workId][user];
    }
}

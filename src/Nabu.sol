// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/console.sol";
import "@solady/src/auth/Ownable.sol";
import "./Ashurbanipal.sol";

error CannotDoubleConfirmPassage(uint256 workId, uint256 passageId);
error InvalidPassageId(uint256 workId, uint256 passageId);
error PassageAlreadyFinalized(uint256 workId, uint256 passageId);
error PermissionDenied(uint256 workId);
error TooSoonToAssignContent(uint256 workId, uint256 passageId, uint256 canAssignAt);

struct Passage {
    // the compressed content of the passage (TODO: compression algorithm)
    bytes content;
    // who performed the assignment or confirmation?
    address by;
    // the block at which `count` last reset or incremented
    uint256 at;
    // how many times the passage's content has been confirmed. assigning new or different content to the passage
    // resets `count` to 0. assigning the same content increments `count`. a passage is considered finalized when
    // `count` reaches 2, at which point only the work's `admin` can assign it new or different content (reseting
    // `count` to 0 in the process)
    uint8 count;
}

struct Work {
    // who wrote the work?
    string author;
    // arbitrary metadata. whatever you want to add
    string metadata;
    // the title of the work
    string title;
    // who initialized the work? `admin` sets `totalPassagesCount` and has the ability to override a finalized passage
    // by resetting `confirmations.count` to 0
    address admin;
    // the total number of passages in the work
    uint256 totalPassagesCount;
    // the block at which the work was created
    uint256 createdAt;
    // metadata uri for the ERC-1155 token id associated with the work (see Ashurbanipal)
    string uri;
}

contract Nabu is Ownable {
    // maps a passage's `count` to the time that must have elapsed before its content can be confirmed or reassigned:
    //   0 => 7,200 blocks (~1 day)
    //   1 => 50,400 blocks (~7 days)
    //   2 => 216,000 blocks (~30 days)
    uint32[3] private CAN_ASSIGN_PASSAGE_CONTENT_AT = [7_200, 50_400, 216_000];

    Ashurbanipal ashurbanipal;

    mapping(uint256 => Work) private _works;
    mapping(uint256 => mapping(uint256 => Passage)) private _passages;
    uint256 private worksTip;

    modifier onlyForASpell(uint256 workId) {
        require(block.number - _works[workId].createdAt < 273_600, "Window to update work details elapsed");
        _;
    }

    modifier onlyWorkAdmin(uint256 workId) {
        require(msg.sender == _works[workId].admin, "Not the work admin");
        _;
    }

    constructor() {
        _initializeOwner(msg.sender);
    }

    function adminAssignPassageContent(uint256 workId, uint256 passageId, bytes memory content)
        public
        onlyOwner
        returns (uint8)
    {
        Work storage work = _works[workId];

        if (passageId > work.totalPassagesCount) {
            revert InvalidPassageId(workId, passageId);
        }

        Passage memory passage = _passages[workId][passageId];

        passage.at = block.number;
        passage.by = msg.sender;
        passage.content = content;
        passage.count = 0;

        return 0; // passage.count
    }

    function assignPassageContent(uint256 workId, uint256 passageId, bytes memory content) public returns (uint8) {
        Work storage work = _works[workId];

        if (passageId > work.totalPassagesCount) {
            revert InvalidPassageId(workId, passageId);
        }

        Passage memory passage = _passages[workId][passageId];

        if (passage.by == msg.sender) {
            revert CannotDoubleConfirmPassage(workId, passageId);
        }

        uint8 count = passage.count;

        if (count > 2) {
            revert PassageAlreadyFinalized(workId, passageId);
        }

        uint256 canAssignAt = CAN_ASSIGN_PASSAGE_CONTENT_AT[count];

        if (block.number - passage.at < canAssignAt) {
            revert TooSoonToAssignContent(workId, passageId, canAssignAt);
        }

        if (ashurbanipal.balanceOf(msg.sender, workId) == 0) {
            revert PermissionDenied(workId);
        }

        if (keccak256(passage.content) == keccak256(content)) {
            passage.count = count + 1;
        } else {
            passage.content = content;
            passage.count = 0;
        }

        passage.at = block.number;

        return passage.count;
    }

    function createWork(
        string memory author,
        string memory metadata,
        string memory title,
        uint256 totalPassagesCount,
        string memory uri,
        uint256 supply
    ) public returns (uint256) {
        worksTip += 1;

        _works[worksTip] = Work(author, metadata, title, msg.sender, totalPassagesCount, block.number, uri);

        ashurbanipal.mint(msg.sender, worksTip, supply, uri);

        return worksTip;
    }

    function getPassageContent(uint256 workId, uint256 passageId) public view returns (bytes memory) {
        return _passages[workId][passageId].content;
    }

    function getWork(uint256 workId) public view returns (Work memory) {
        return _works[workId];
    }

    function updateAshurbanipalAddress(address newAshurbanipalAddress) public onlyOwner {
        ashurbanipal = Ashurbanipal(newAshurbanipalAddress);
    }

    function updateWorkAdmin(uint256 workId, address newAdmin) public onlyWorkAdmin(workId) {
        _works[workId].admin = newAdmin;
    }

    function updateWorkAuthor(uint256 workId, string memory newAuthor)
        public
        onlyForASpell(workId)
        onlyWorkAdmin(workId)
    {
        _works[workId].author = newAuthor;
    }

    function updateWorkMetadata(uint256 workId, string memory newMetadata)
        public
        onlyForASpell(workId)
        onlyWorkAdmin(workId)
    {
        _works[workId].metadata = newMetadata;
    }

    function updateWorkNftUri(uint256 workId, string memory newUri)
        public
        onlyForASpell(workId)
        onlyWorkAdmin(workId)
    {
        ashurbanipal.updateUri(workId, newUri);
    }

    function updateWorkTitle(uint256 workId, string memory newTitle)
        public
        onlyForASpell(workId)
        onlyWorkAdmin(workId)
    {
        _works[workId].title = newTitle;
    }

    function updateWorkTotalPassagesCount(uint256 workId, uint256 newTotalPassagesCount)
        public
        onlyForASpell(workId)
        onlyWorkAdmin(workId)
    {
        _works[workId].totalPassagesCount = newTotalPassagesCount;
    }
}

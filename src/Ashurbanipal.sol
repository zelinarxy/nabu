// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/console.sol";
import "@solady/src/tokens/ERC1155.sol";
import "@solady/src/auth/Ownable.sol";

error NotNabu();

contract Ashurbanipal is ERC1155, Ownable {
    address private _nabuAddress;

    mapping(uint256 => string) private _uris;

    modifier onlyNabu() {
        require(msg.sender == _nabuAddress, NotNabu());
        _;
    }

    constructor(address initialNabuAddress) ERC1155() {
        _nabuAddress = initialNabuAddress;
    }

    function mint(address account, uint256 workId, uint256 supply, string memory workUri) public onlyNabu {
        _mint(account, workId, supply, "");
        _uris[workId] = workUri;
    }

    function nabuAddress() public returns (address) {
        return _nabuAddress;
    }

    function updateUri(uint256 workId, string memory newUri) public onlyNabu {
        _uris[workId] = newUri;
    }

    function uri(uint256 workId) public view override returns (string memory) {
        return _uris[workId];
    }
}

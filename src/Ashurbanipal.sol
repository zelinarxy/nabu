// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/console.sol";
import "@solady/src/tokens/ERC1155.sol";
import "@solady/src/auth/Ownable.sol";

contract Ashurbanipal is ERC1155, Ownable {
    address nabuAddress;

    mapping(uint256 => string) private _uris;

    modifier onlyNabu() {
        require(msg.sender == nabuAddress, "Not Nabu");
        _;
    }

    constructor(address initialNabuAddress) ERC1155() {
        nabuAddress = initialNabuAddress;
    }

    function mint(address account, uint256 id, uint256 supply, string memory workUri) public onlyNabu {
        _mint(account, id, supply, "");
        _uris[id] = workUri;
    }

    function updateUri(uint256 id, string memory newUri) public onlyNabu {
        _uris[id] = newUri;
    }

    function uri(uint256 id) public view override returns (string memory) {
        return _uris[id];
    }
}

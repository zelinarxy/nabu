// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@solady/src/auth/Ownable.sol";
import {ERC20} from "@solady/src/tokens/ERC20.sol";
import {ERC721} from "@solady/src/tokens/ERC721.sol";
import {Receiver} from "@solady/src/accounts/Receiver.sol";
import {SSTORE2} from "@solady/src/utils/SSTORE2.sol";
import "./Ashurbanipal.sol";

error Inactive();
error InsufficientFunds();
error OverLimit();
error ZeroCount();

enum WhitelistedToken {
    Any,
    None,
    Cult,
    Aura,
    Cigawrette,
    Milady,
    Pixelady,
    Radbro,
    Remilio,
    Schizoposter,
    TestNft
}

// Whitelisted fungible token
address constant CULT = 0x0000000000c5dc95539589fbD24BE07c6C14eCa4;

// Whitelisted NFTs
address constant AURA = 0x2fC722C1c77170A61F17962CC4D039692f033b43;
address constant CIGAWRETTE = 0xEEd41d06AE195CA8f5CaCACE4cd691EE75F0683f;
address constant MILADY = 0x5Af0D9827E0c53E4799BB226655A1de152A425a5;
address constant PIXELADY = 0x8Fc0D90f2C45a5e7f94904075c952e0943CFCCfd;
address constant RADBRO = 0xABCDB5710B88f456fED1e99025379e2969F29610;
address constant REMILIO = 0xD3D9ddd0CF0A5F0BFB8f7fcEAe075DF687eAEBaB;
address constant SCHIZOPOSTER = 0xBfE47D6D4090940D1c7a0066B63d23875E3e2Ac5;

// Free mints per whitelisted user (user who holds one or more whitelisted assets)
uint256 constant FREE_MINTS = 7;
uint256 constant MINT_LIMIT = 69;

/// @title A mint contract for distributing Ashurbanipal passes
///
/// @author Zelinar XY
contract Enkidu is Ownable, Receiver {
    ERC20 private cult;

    ERC721 private aura;
    ERC721 private cigawrette;
    ERC721 private milady;
    ERC721 private pixelady;
    ERC721 private radbro;
    ERC721 private remilio;
    ERC721 private schizoposter;
    ERC721 private testNft; // TODO

    Ashurbanipal private _ashurbanipal;
    address public ashurbanipalAddress;

    // maps id to price
    mapping(uint256 => uint256) public prices;
    // id
    mapping(uint256 => bool) public active;

    // how many free mints has a user used for an id
    mapping(uint256 => mapping(address => uint256)) public freeMints;

    constructor(address initialAshurbanipalAddress, address testNftAddress) {
        _initializeOwner(msg.sender);
        ashurbanipalAddress = initialAshurbanipalAddress;
        _ashurbanipal = Ashurbanipal(initialAshurbanipalAddress);

        cult = ERC20(CULT);

        aura = ERC721(AURA);
        cigawrette = ERC721(CIGAWRETTE);
        milady = ERC721(MILADY);
        pixelady = ERC721(PIXELADY);
        radbro = ERC721(RADBRO);
        remilio = ERC721(REMILIO);
        schizoposter = ERC721(SCHIZOPOSTER);
        testNft = ERC721(testNftAddress);
    }

    function _mint(uint256 id, uint256 count, address to) private {
        if (count == 0) {
            revert ZeroCount();
        }

        _ashurbanipal.safeTransferFrom(address(this), to, id, count, "");
    }

    function adminMint(uint256 id, uint256 count, address to) public onlyOwner {
        _mint(id, count, to);
    }

    // To save gas, the consuming application should check the user's token balances before calling
    // this function and pass an appropriate value for `whitelistedToken`. For example, if the user
    // has already minted 7 free tokens, we know they're not eligible to mint any more for free, and
    // we can pass `WhitelistedToken.None` to skip the check. If we know they have a Milady, we can
    // pass `WhitelistedToken.Milady` rather than looping through every collection. If we're not sure,
    // we can pass `WhitelistedToken.Any` to run the exhaustive check.
    function mint(uint256 id, uint256 count, address to, WhitelistedToken whitelistedToken) public payable {
        if (!active[id]) {
            revert Inactive();
        }

        uint256 existingBalance = _ashurbanipal.balanceOf(to, id);

        if (count + existingBalance > MINT_LIMIT) {
            revert OverLimit();
        }

        uint256 usedFreeMints = freeMints[id][to];
        uint256 remainingFreeMints;

        if (usedFreeMints > FREE_MINTS) {
            remainingFreeMints = 0;
        } else {
            remainingFreeMints = FREE_MINTS - usedFreeMints;
        }

        bool isWhitelisted;

        if (whitelistedToken == WhitelistedToken.Cult) {
            isWhitelisted = cult.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Aura) {
            isWhitelisted = aura.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Cigawrette) {
            isWhitelisted = cigawrette.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Milady) {
            isWhitelisted = milady.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Pixelady) {
            isWhitelisted = milady.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Radbro) {
            isWhitelisted = radbro.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Remilio) {
            isWhitelisted = remilio.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Schizoposter) {
            isWhitelisted = schizoposter.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.TestNft) {
            isWhitelisted = testNft.balanceOf(to) > 0;
        }

        if (whitelistedToken == WhitelistedToken.Any || (!isWhitelisted && whitelistedToken != WhitelistedToken.None)) {
            isWhitelisted = cult.balanceOf(to) > 0 || aura.balanceOf(to) > 0 || cigawrette.balanceOf(to) > 0
                || milady.balanceOf(to) > 0 || pixelady.balanceOf(to) > 0 || radbro.balanceOf(to) > 0
                || remilio.balanceOf(to) > 0 || schizoposter.balanceOf(to) > 0 || testNft.balanceOf(to) > 0;
        }

        uint256 countForPrice = count;

        if (isWhitelisted) {
            if (countForPrice < remainingFreeMints) {
                countForPrice = 0;
            } else {
                countForPrice -= remainingFreeMints;
            }
        }

        uint256 pricePerUnit = prices[id];
        uint256 price = pricePerUnit * countForPrice;

        if (msg.value < price) {
            revert InsufficientFunds();
        }

        _mint(id, count, to);

        if (countForPrice < count) {
            freeMints[id][to] = freeMints[id][to] + countForPrice - count;
        }
    }

    function updateActive(uint256 id, bool isActive) public onlyOwner {
        active[id] = isActive;
    }

    function updatePrice(uint256 id, uint256 price) public onlyOwner {
        prices[id] = price;
    }

    function updateAshurbanipalAddress(address newAshurbanipalAddress) public onlyOwner {
        ashurbanipalAddress = newAshurbanipalAddress;
        _ashurbanipal = Ashurbanipal(newAshurbanipalAddress);
    }

    function withdraw(uint256 amount) public onlyOwner {
        uint256 amountToWithdraw = amount;

        if (amountToWithdraw == 0) {
            amountToWithdraw = address(this).balance;
        }

        payable(msg.sender).transfer(amountToWithdraw);
    }
}

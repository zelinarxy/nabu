// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "lib/solady/src/tokens/ERC20.sol";
import {ERC721} from "lib/solady/src/tokens/ERC721.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";
import {Receiver} from "lib/solady/src/accounts/Receiver.sol";

import {Ashurbanipal} from "./Ashurbanipal.sol";

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                          ERRORS                            */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

/// @dev Can't mint inactive ids
error Inactive();
/// @dev The value of the transaction is too low to successfully mint
error InsufficientFunds();
/// @dev The attempted mint puts the user over the per-address limit on total mints per id
error OverLimit();
/// @dev Can't mint zero passes
error ZeroCount();

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                          EVENTS                            */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

event ActiveUpdated(uint256 id, bool isActive);

event AdminMinted(uint256 id, uint256 count, address to);

event AshurbanipalUpdated(address newAshurbanipalAddress);

event HumbabaUpdated(address newHumbabaAddress);

event Minted(uint256 id, uint256 count, address to, uint256 price, WhitelistedToken whitelistedToken);

event PriceUpdated(uint256 id, uint256 price);

/**
 * @dev Owners of a number of Remilia assets are whitelisted: they can mint up to a certain number of passes per id
 * for free. The same is the case for owners of Humbaba NFTs, assuming a Humbaba contract has been deployed and
 * associated with this Enkidu instance. To save gas, it's the responsibility of the caller of the `mint` function to
 * be aware of the user's portfolio and specify the asset, if any, that grants them whitelisted status. If none, the
 * caller can specify `None` and avoid a series of balance checks. If the caller is uncertain, `Any` will check all
 * eligible assets.
 */
enum WhitelistedToken {
    /* Meta */
    Any, // 0
    None, // 1
    /* Fungible */
    Cult, // 2
    /* Remilia NFTs */
    Aura, // 3
    Cigawrette, // 4
    Milady, // 5
    Pixelady, // 6
    Radbro, // 7
    Remilio, // 8
    Schizoposter, // 9
    /* Admin NFT */
    Humbaba // 10
}

/// @dev Whitelisted token: Cult
address constant CULT = 0x0000000000c5dc95539589fbD24BE07c6C14eCa4;

/// @dev Whitelisted NFT: MiladyAura
address constant AURA = 0x2fC722C1c77170A61F17962CC4D039692f033b43;
/// @dev Whitelisted NFT: Cigawrettes
address constant CIGAWRETTE = 0xEEd41d06AE195CA8f5CaCACE4cd691EE75F0683f;
/// @dev Whitelisted NFT: Milady
address constant MILADY = 0x5Af0D9827E0c53E4799BB226655A1de152A425a5;
/// @dev Whitelisted NFT: Pixelady
address constant PIXELADY = 0x8Fc0D90f2C45a5e7f94904075c952e0943CFCCfd;
/// @dev Whitelisted NFT: Radbro
address constant RADBRO = 0xABCDB5710B88f456fED1e99025379e2969F29610;
/// @dev Whitelisted NFT: Remilio
address constant REMILIO = 0xD3D9ddd0CF0A5F0BFB8f7fcEAe075DF687eAEBaB;
/// @dev Whitelisted NFT: SchizoPosters
address constant SCHIZOPOSTER = 0xBfE47D6D4090940D1c7a0066B63d23875E3e2Ac5;

/// @dev Maximum free mints per id per whitelisted user
uint256 constant FREE_MINTS = 7;

/// @dev Maximum mints per id per user
uint256 constant MINT_LIMIT = 69;

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                          𒂗𒆠𒄭                            */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

/// @title A mint contract for distributing Ashurbanipal NFTs
///
/// @author Zelinar XY
contract Enkidu is Ownable, Receiver {
    Ashurbanipal private _ashurbanipal;

    ERC721 private _humbaba;

    /// @notice Map Ashurbanipal ids (corresponding to a Nabu works) to their prices
    mapping(uint256 id => uint256 price) public prices;

    /// @notice Map Ashurbanipal ids (corresponding to a Nabu works) to whether they are active (i.e., can be minted)
    mapping(uint256 id => bool isActive) public active;

    /// @notice How many free mints have been used up per id
    mapping(uint256 id => mapping(address user => uint256 mintsCount)) public usedFreeMints;

    /// @notice Initialize the contract with Ashurbanipal and Humbaba addresses and an owner who can update them
    ///
    /// @param initialAshurbanipalAddress The Ashurbanipal contract address
    /// @param initialHumbabaAddress The Humbaba contract address (optional)
    constructor(address initialAshurbanipalAddress, address initialHumbabaAddress) {
        _initializeOwner(msg.sender);

        _ashurbanipal = Ashurbanipal(initialAshurbanipalAddress);
        _humbaba = ERC721(initialHumbabaAddress);
    }

    /// @notice Get the Ashurbanipal contract address
    ///
    /// @return The contract address
    function getAshurbanipalAddress() external view returns (address) {
        return address(_ashurbanipal);
    }

    /// @notice Get the Humbaba contract address
    ///
    /// @return The contract address
    function getHumbabaAddress() external view returns (address) {
        return address(_humbaba);
    }

    /// @notice Update the Humbaba address and contract instance
    ///
    /// @dev Only the contract owner can call this function
    function updateHumbaba(address newHumbabaAddress) external onlyOwner {
        _humbaba = ERC721(newHumbabaAddress);
        emit HumbabaUpdated(newHumbabaAddress);
    }

    /// @dev Returns true if `account` holds any balance of the specified whitelisted token.
    /// @dev For `Any`, exhaustively checks all collections (short-circuits on the first match).
    function _isWhitelisted(address account, WhitelistedToken token) private view returns (bool) {
        if (token == WhitelistedToken.Cult) return ERC20(CULT).balanceOf(account) > 0;
        if (token == WhitelistedToken.Aura) return ERC721(AURA).balanceOf(account) > 0;
        if (token == WhitelistedToken.Cigawrette) return ERC721(CIGAWRETTE).balanceOf(account) > 0;
        if (token == WhitelistedToken.Milady) return ERC721(MILADY).balanceOf(account) > 0;
        if (token == WhitelistedToken.Pixelady) return ERC721(PIXELADY).balanceOf(account) > 0;
        if (token == WhitelistedToken.Radbro) return ERC721(RADBRO).balanceOf(account) > 0;
        if (token == WhitelistedToken.Remilio) return ERC721(REMILIO).balanceOf(account) > 0;
        if (token == WhitelistedToken.Schizoposter) return ERC721(SCHIZOPOSTER).balanceOf(account) > 0;
        if (token == WhitelistedToken.Humbaba) return _humbaba.balanceOf(account) > 0;

        if (token == WhitelistedToken.Any) {
            return _isWhitelisted(account, WhitelistedToken.Cult) || _isWhitelisted(account, WhitelistedToken.Aura)
                || _isWhitelisted(account, WhitelistedToken.Cigawrette)
                || _isWhitelisted(account, WhitelistedToken.Milady)
                || _isWhitelisted(account, WhitelistedToken.Pixelady)
                || _isWhitelisted(account, WhitelistedToken.Radbro) || _isWhitelisted(account, WhitelistedToken.Remilio)
                || _isWhitelisted(account, WhitelistedToken.Schizoposter)
                || _isWhitelisted(account, WhitelistedToken.Humbaba);
        }

        return false; // WhitelistedToken.None
    }

    /// @notice Transfer a quantity of Ashurbanipal NFTS to the caller or specified recipient
    ///
    /// @param id The id of the Ashurbanipal NFT
    /// @param count The quantity of NFTs to transfer
    /// @param to The recipient
    function _distribute(uint256 id, uint256 count, address to) private {
        if (count == 0) {
            revert ZeroCount();
        }

        _ashurbanipal.safeTransferFrom({from: address(this), to: to, id: id, amount: count, data: ""});
    }

    /// @notice Transfer Ashurbanipal NFTs to a recipient for free
    ///
    /// @dev Only the contract owner can call this function
    ///
    /// @param id The id of the Ashurbanipal NFT
    /// @param count The quantity of NFTs to transfer
    /// @param to The recipient
    function adminMint(uint256 id, uint256 count, address to) external onlyOwner {
        _distribute({id: id, count: count, to: to});
        emit AdminMinted({id: id, count: count, to: to});
    }

    /// @notice Public "mint" function to transfer a quantity of Ashurbanipal NFTs to a recipient
    ///
    /// @dev The NFTs already exist and are held by the Ashurbanipal contract; "mint" reflects the end-user experience
    /// @dev The caller should specify what whitelisted token they hold (see comment on the `WhitelistedToken` enum)
    ///
    /// @param id The id of the Ashurbanipal NFT
    /// @param count The quantity of NFTs to transfer
    /// @param to The recipient
    /// @param whitelistedToken A specific whitelistedToken the recipient holds (or `Any` or `None`)
    function mint(uint256 id, uint256 count, address to, WhitelistedToken whitelistedToken) external payable {
        if (!active[id]) {
            revert Inactive();
        }

        uint256 existingBalance = _ashurbanipal.balanceOf({owner: to, id: id});

        // Users can only mint a certain total count per id, regardless of whitelist status
        if (count + existingBalance > MINT_LIMIT) {
            revert OverLimit();
        }

        // Track the number of free mints expended per user per id. Otherwise holders of whitelisted collections could
        // mint endless free Ashurbanipal passes by calling the function multiple times.
        uint256 usedFree = usedFreeMints[id][to];
        uint256 remainingFreeMints;

        if (usedFree >= FREE_MINTS) {
            remainingFreeMints = 0;
        } else {
            remainingFreeMints = FREE_MINTS - usedFree;
        }

        // Does the user hold a whitelisted collection?
        bool isWhitelisted;

        // No need to perform any checks if the user has maxed out on free mints
        if (remainingFreeMints > 0) {
            isWhitelisted = _isWhitelisted(to, whitelistedToken);
        }

        // Calculate the total cost of the transaction
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

        // Prevent reentrancy
        if (countForPrice < count) {
            usedFreeMints[id][to] = usedFree + count - countForPrice;
        }

        // Transfer the passes
        _distribute({id: id, count: count, to: to});
        emit Minted({id: id, count: count, to: to, price: price, whitelistedToken: whitelistedToken});
    }

    /// @notice Update the `active` status for an id
    ///
    /// @dev Only the contract owner can call this function
    ///
    /// @param id The id of the Ashurbanipal NFT
    /// @param isActive The new value for `active`
    function updateActive(uint256 id, bool isActive) external onlyOwner {
        active[id] = isActive;
        emit ActiveUpdated({id: id, isActive: isActive});
    }

    /// @notice Update the price for an id
    ///
    /// @dev Only the contract owner can call this function
    ///
    /// @param id The id of the Ashurbanipal NFT
    /// @param price The new price
    function updatePrice(uint256 id, uint256 price) external onlyOwner {
        prices[id] = price;
        emit PriceUpdated({id: id, price: price});
    }

    /// @notice Update the Ashurbanipal address and contract instance
    ///
    /// @dev Only the contract owner can call this function
    ///
    /// @param newAshurbanipalAddress The new contract address
    function updateAshurbanipal(address newAshurbanipalAddress) external onlyOwner {
        _ashurbanipal = Ashurbanipal(newAshurbanipalAddress);
        emit AshurbanipalUpdated(newAshurbanipalAddress);
    }

    /// @notice Withdraw mint proceeds
    ///
    /// @dev Only the contract owner can call this function
    /// @dev This function has no reentrancy guard: do not withdraw to an unvetted address
    ///
    /// @param amount The amount to withdraw; if zero, falls back to the entire balance
    /// @param to The recipient of the withdrawn funds; falls back to msg.sender
    function withdraw(uint256 amount, address to) external onlyOwner {
        uint256 amountToWithdraw = amount;

        if (amountToWithdraw == 0) {
            amountToWithdraw = address(this).balance;
        }

        address recipient = to;

        if (to == address(0)) {
            recipient = msg.sender;
        }

        (bool success,) = payable(recipient).call{value: amountToWithdraw}("");
        require(success);
    }
}

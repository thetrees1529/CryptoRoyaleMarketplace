//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "utils/contracts/payments/Fees.sol";
import "utils/contracts/payments/ERC20Payments.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


interface IBuyItNow {

    function setFee(Fees.Fee memory fee) external;

    function getFee() external view returns(Fees.Fee memory);

    function collectFees() external;

    function getFeesCollected() external view returns(uint);

    function list(uint tokenId, uint price) external;

    function purchase(uint listingId, uint expectedPrice) external;

    function editPrice(uint listingId, uint newPrice) external;

    function cancel(uint listingId) external;

    event Listed(string listingId, address seller, uint tokenId, uint price);
    event Sold(string listingId, address buyer);
    event PriceEdited(string listingId, uint newPrice);
    event Cancelled(string listingId);

}

contract BuyItNow is IBuyItNow, Ownable, ERC1155Holder, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Fees for uint;
    using Strings for uint;
    
    IERC1155 private _skins;
    IERC20 private _roy;

    constructor(IERC1155 skins, IERC20 roy) {
        _skins = skins;
        _roy = roy;
    }

    struct Listing {
        address seller;
        uint tokenId;
        uint price;
        bool active;
    }

    Fees.Fee private _fee;
    Listing[] private _listings;
    uint private _feesCollected;

    function setFee(Fees.Fee memory fee) external override onlyOwner {
        _fee = fee;
    }

    function getFee() external override view returns(Fees.Fee memory) {
        return _fee;
    }

    function collectFees() external override onlyOwner {
        _roy.safeTransfer(msg.sender, _feesCollected);
        delete _feesCollected;
    }

    function getFeesCollected() external override view returns(uint) {
        return _feesCollected;
    }

    function list(uint tokenId, uint price) external override nonReentrant {
        address seller = msg.sender;
        _transferOneSkinFrom(seller, address(this), tokenId);
        uint listingId = _listings.length;
        _listings.push(
            Listing(
                {
                    tokenId: tokenId,
                    price: price,
                    active: true,
                    seller: seller
                }
            )
        );
        emit Listed(listingId.toString(), seller, tokenId, price);
    }

    function purchase(uint listingId, uint expectedPrice) external override nonReentrant {
        address buyer = msg.sender;
        Listing storage listing = _listings[listingId];
        require(listing.active, "Cannot purchase inactive listing.");
        require(listing.price == expectedPrice, "Price has changed.");
        uint fees = listing.price.feesOf(_fee);
        uint toSeller = listing.price - fees;
        _feesCollected += fees;
        _roy.safeTransferFrom(buyer, listing.seller, toSeller);
        _roy.safeTransferFrom(buyer, address(this), fees);
        _transferOneSkinFrom(address(this), buyer, listing.tokenId);
        listing.active = false;
        emit Sold(listingId.toString(), buyer);
    }

    function editPrice(uint listingId, uint newPrice) external override nonReentrant {
        Listing storage listing = _listings[listingId];
        require(listing.active, "Cannot edit inactive listing.");
        require(msg.sender == listing.seller, "You aren't the seller of this listing.");
        listing.price = newPrice;
        emit PriceEdited(listingId.toString(), newPrice);
    }

    function cancel(uint listingId) external override nonReentrant {
        address seller = msg.sender;
        Listing storage listing = _listings[listingId];
        require(listing.active, "Cannot cancel inactive listing.");
        require(seller == listing.seller, "You aren't the seller of this listing.");
        _transferOneSkinFrom(address(this), seller, listing.tokenId);
        listing.active = false;
        emit Cancelled(listingId.toString());
    }

    function _transferOneSkinFrom(address from, address to, uint tokenId) private {
        _skins.safeTransferFrom(from, to, tokenId, 1, "");
    }

}
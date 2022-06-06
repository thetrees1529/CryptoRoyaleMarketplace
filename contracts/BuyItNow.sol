//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "utils/contracts/payments/Fees.sol";
import "utils/contracts/payments/ERC20Payments.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IBuyItNow {

    function setFee(Fees.Fee memory fee) external;

    function getFee() external  view returns(Fees.Fee memory);

    function approveCollection(address collection) external;

    function unapproveCollection(address collection) external;

    function isApprovedCollection(address collection) external view returns(bool);

    function getApprovedCollections() external view returns(address[] memory);

    function collectFees() external;

    function getFeesCollected() external  view returns(uint);

    function list(address nft, uint tokenId, uint price) external;

    function purchase(uint listingId, uint expectedPrice) external;

    function editPrice(uint listingId, uint newPrice) external;

    function cancel(uint listingId) external;

    event Listed(string listingId, address seller, address nft, uint tokenId, uint price);
    event Sold(string listingId, address buyer);
    event PriceEdited(string listingId, uint newPrice);
    event Cancelled(string listingId);

}

contract BuyItNow is IBuyItNow, Ownable, ERC1155Holder, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using Fees for uint;
    using Strings for uint;
    
    IERC20 private _roy;

    constructor(IERC20 roy) {
        _roy = roy;
    }

    struct Listing {
        address seller;
        address nft;
        uint tokenId;
        uint price;
        bool active;
    }

    Fees.Fee private _fee;
    Listing[] private _listings;
    uint private _feesCollected;
    EnumerableSet.AddressSet private _approvedCollections;

    function setFee(Fees.Fee memory fee) external override  onlyOwner {
        _fee = fee;
    }

    function getFee() external override  view returns(Fees.Fee memory) {
        return _fee;
    }

    function approveCollection(address collection) external override  onlyOwner {
        _approvedCollections.add(collection);
    }

    function unapproveCollection(address collection) external override  onlyOwner {
        _approvedCollections.remove(collection);
    }

    function isApprovedCollection(address collection) public override view returns(bool) {
        return _approvedCollections.contains(collection);
    }

    function getApprovedCollections() external override view returns(address[] memory) {
        return _approvedCollections.values();
    }

    function collectFees() external override  onlyOwner {
        _roy.safeTransfer(msg.sender, _feesCollected);
        delete _feesCollected;
    }

    function getFeesCollected() external override  view returns(uint) {
        return _feesCollected;
    }

    function list(address nft, uint tokenId, uint price) external override  nonReentrant {
        require(isApprovedCollection(nft), "Nft collection is not approved for this marketplace.");
        address seller = msg.sender;

        _transferNftFrom(nft, seller, address(this), tokenId);        

        uint listingId = _listings.length;
        _listings.push(
            Listing(
                {
                    nft: nft,
                    tokenId: tokenId,
                    price: price,
                    active: true,
                    seller: seller
                }
            )
        );
        emit Listed(listingId.toString(), seller, nft, tokenId, price);
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


        _transferNftFrom(listing.nft, address(this), buyer, listing.tokenId);

        listing.active = false;
        emit Sold(listingId.toString(), buyer);
    }

    function editPrice(uint listingId, uint newPrice) external override  nonReentrant {
        Listing storage listing = _listings[listingId];
        require(listing.active, "Cannot edit inactive listing.");
        require(msg.sender == listing.seller, "You aren't the seller of this listing.");
        listing.price = newPrice;
        emit PriceEdited(listingId.toString(), newPrice);
    }

    function cancel(uint listingId) external override  nonReentrant {
        address seller = msg.sender;
        Listing storage listing = _listings[listingId];
        require(listing.active, "Cannot cancel inactive listing.");
        require(seller == listing.seller, "You aren't the seller of this listing.");

    
        _transferNftFrom(listing.nft, address(this), seller, listing.tokenId);
        listing.active = false;
        emit Cancelled(listingId.toString());
    }


    function _transferNftFrom(address nft, address from, address to, uint tokenId) private {
        bool isERC721 = IERC165(nft).supportsInterface(type(IERC721).interfaceId);
        if(isERC721) {
            IERC721(nft).safeTransferFrom(from, to, tokenId);
        } else {
            IERC1155(nft).safeTransferFrom(from, to, tokenId, 1, "");
        }
    }

}
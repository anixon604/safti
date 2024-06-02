// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./SafeTi.sol";

contract VickreyAuction {
    using SafeMath for uint256;

    IERC721 public propertyToken;
    address internal propertyTokenAddress;

    mapping(address => uint256) public bids;
    address[] private bidders;

    struct Auction {
        uint256 auctionUUID;
        uint256 propertyTokenId;
        address landlord;
        uint256 auctionEndTime;
        address highestBidder;
        uint256 highestBid;
        uint256 secondHighestBid;
    }

    // auctionUUID (auctionEndTime plus propertyTokenId)
    mapping(uint256 => Auction) public auctions;

    bool public ended;

    event AuctionEnded(address winner, uint256 highestBid);
    event AuctionEndedNoBids(string msg);
    event AuctionResults(Auction auction);
    
    modifier onlyBefore(uint _time) {
        require(block.timestamp < _time, "Function called too late.");
        _;
    }

    modifier onlyAfter(uint _time) {
        require(block.timestamp > _time, "Function called too early.");
        _;
    }

    constructor() {
    }

    function createAuction(
        address _propertyToken,
        uint256 _propertyTokenId,
        uint256 auctionDuration
    ) public returns (Auction memory auctionResponse){
        propertyToken = IERC721(_propertyToken);
        propertyTokenAddress = _propertyToken;
        
        uint256 auctionEndTime = block.timestamp + auctionDuration;
        uint256 auctionUUID = auctionEndTime+_propertyTokenId;
        auctions[auctionUUID] = Auction({
            auctionUUID: auctionUUID,
            propertyTokenId: _propertyTokenId,
            landlord: msg.sender,
            auctionEndTime: auctionEndTime,
            highestBidder: address(0),
            highestBid: 0,
            secondHighestBid: 0
        });
        require(propertyToken.ownerOf(_propertyTokenId) == msg.sender, "Only owner/landlord able to create.");
        return auctions[auctionUUID];
    }

    function bid(uint256 auctionUUID) external payable onlyBefore(auctions[auctionUUID].auctionEndTime) {
        Auction storage currentAuction = auctions[auctionUUID];
        require(!ended, "Auction ended already.");
        require(msg.sender != currentAuction.landlord, "Landlord cannot bid on own property");
        require(msg.value > 0, "Proposed bid must be greater than 0");

        if (bids[msg.sender] == 0) {
            bidders.push(msg.sender);
        }
        bids[msg.sender] = bids[msg.sender].add(msg.value);

        if (bids[msg.sender] > currentAuction.highestBid) {
            currentAuction.secondHighestBid = currentAuction.highestBid;
            currentAuction.highestBid = bids[msg.sender];
            currentAuction.highestBidder = payable(msg.sender);
        } else if (bids[msg.sender] > currentAuction.secondHighestBid) {
            currentAuction.secondHighestBid = bids[msg.sender];
        }
    }

    function end(uint256 auctionUUID) internal {
        require(!ended, "Auction already ended.");

        ended = true;
        if (auctions[auctionUUID].highestBid == 0) {
            emit AuctionEndedNoBids("Auction ended with no bids.");
            return;
        }

        emit AuctionEnded(auctions[auctionUUID].highestBidder, auctions[auctionUUID].highestBid);

        // Set winning details to lease
        uint256 tokenID = auctions[auctionUUID].propertyTokenId;
        SafeTi sft = SafeTi(propertyTokenAddress);
        sft.startLease(tokenID, auctions[auctionUUID].highestBidder, auctions[auctionUUID].highestBid);
    }

    function payOutToLandlord(uint256 auctionUUID, uint256 amount) internal {
        require(amount > 0, "No funds to payout.");
        (bool sent, ) = auctions[auctionUUID].landlord.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    function endAuction(uint256 auctionUUID) external onlyAfter(auctions[auctionUUID].auctionEndTime) {
        end(auctionUUID);
    }

    function endEarly(uint256 auctionUUID) external {
        require(msg.sender == auctions[auctionUUID].landlord, "Only landlord can end early.");
        end(auctionUUID);
    }

    function withdraw(uint256 auctionUUID) external onlyAfter(auctions[auctionUUID].auctionEndTime) {
        uint256 amount = bids[msg.sender];

        require(amount > 0, "No funds to withdraw.");
        // Prevent re-entrancy attack
        bids[msg.sender] = 0;

        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    function getAuctionResult(uint256 auctionUUID) external view onlyAfter(auctions[auctionUUID].auctionEndTime) returns (address highestBidder, uint256 highestBid, uint256 secondHighestBid) {
        highestBidder = auctions[auctionUUID].highestBidder;
        highestBid = auctions[auctionUUID].highestBid;
        secondHighestBid = auctions[auctionUUID].secondHighestBid;
    }
}

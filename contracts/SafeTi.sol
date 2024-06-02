// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SafeTi is ERC721, Ownable {
    using SafeMath for uint256;

    struct RentalDetails {
        address landlord;
        address tenant;
        uint256 rentAmount; // Monthly rent amount in wei
        uint256 securityDeposit; // Security deposit amount in wei
        uint256 leaseStart; // Lease start timestamp
        uint256 leaseEnd; // Lease end timestamp
        bool isLeased; // Lease status
    }

    struct PropertyDetails {
        string flatAddress;
        uint256 rooms;
    }

    uint256 public tokenIdCounter = 0;
    modifier OnlyLandlord(uint256 tokenId) {
        // Check if the caller is the landlord of the token. If not, revert.
        if (msg.sender != rentalDetails[tokenId].landlord) {
            revert("SafeTi: Only landlord can call this function");
        }
        _;
    }
    mapping(uint256 => RentalDetails) public rentalDetails;
    mapping(uint256 => PropertyDetails) public propertyDetails;

    // owner is the authorized tenant.
    constructor() 
        ERC721("SafeTi", "SFT")
        Ownable(msg.sender)
    {}

    function createLease(
        string memory flatAddress,
        uint256 numRooms,
        uint256 leaseDuration
    ) public onlyOwner {
        require(leaseDuration > 0, "SafeT: lease duration must be greater than 0");

        tokenIdCounter += 1;
        // uint256 securityDeposit = rentAmount*5/10;

        uint256 leaseStart = block.timestamp;
        uint256 leaseEnd = leaseStart + leaseDuration * 1 days;
        address landlord = msg.sender;

        _safeMint(landlord, tokenIdCounter);
        propertyDetails[tokenIdCounter] = PropertyDetails({
            flatAddress: flatAddress,
            rooms: numRooms
        });
        rentalDetails[tokenIdCounter] = RentalDetails({
            landlord: landlord,
            tenant: address(0),
            rentAmount: 0,
            securityDeposit: 0,
            leaseStart: leaseStart,
            leaseEnd: leaseEnd,
            isLeased: false
        });
    }

    function startLease(uint256 _tokenId, address _tenant, uint256 _rentAmount) public returns (RentalDetails memory) {
        rentalDetails[_tokenId].tenant = _tenant;
        rentalDetails[_tokenId].rentAmount = _rentAmount;
        rentalDetails[_tokenId].securityDeposit = _rentAmount;
        return rentalDetails[_tokenId];
    }

    function endLease(uint256 tokenId) public OnlyLandlord(tokenId) {
        require(rentalDetails[tokenId].leaseStart <= block.timestamp, "SafeTi: lease has not started yet");
        rentalDetails[tokenId].isLeased = false;
    }

    function getRentalDetails(uint256 tokenId) public view returns (RentalDetails memory) {
        return rentalDetails[tokenId];
    }

    function getPropertyDetails(uint256 tokenId) public view returns (PropertyDetails memory) {
        return propertyDetails[tokenId];
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ProfileNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct Profile {
        string bio;
        string[] skills;
        address[] badges;
        address[] poaps;
        bool isActive;
    }

    // Mapping from token ID to Profile
    mapping(uint256 => Profile) public profiles;
    
    // Mapping from address to token ID
    mapping(address => uint256) public addressToProfileId;
    
    // Mapping to track if an address has a profile
    mapping(address => bool) public hasProfile;

    event ProfileCreated(uint256 indexed tokenId, address indexed owner);
    event BadgeAdded(uint256 indexed tokenId, address indexed badgeAddress);
    event POAPAdded(uint256 indexed tokenId, address indexed poapAddress);
    event ProfileUpdated(uint256 indexed tokenId);

    constructor() ERC721("Greenroom Profile", "GRP") Ownable(msg.sender) {}

    function createProfile(
        string memory bio,
        string[] memory skills,
        string memory tokenURI
    ) public returns (uint256) {
        require(!hasProfile[msg.sender], "Profile already exists for this address");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        
        profiles[newTokenId] = Profile({
            bio: bio,
            skills: skills,
            badges: new address[](0),
            poaps: new address[](0),
            isActive: true
        });
        
        addressToProfileId[msg.sender] = newTokenId;
        hasProfile[msg.sender] = true;
        
        emit ProfileCreated(newTokenId, msg.sender);
        return newTokenId;
    }

    function addBadge(address badgeAddress) public {
        require(hasProfile[msg.sender], "Profile does not exist");
        uint256 tokenId = addressToProfileId[msg.sender];
        
        profiles[tokenId].badges.push(badgeAddress);
        emit BadgeAdded(tokenId, badgeAddress);
    }

    function addPOAP(address poapAddress) public {
        require(hasProfile[msg.sender], "Profile does not exist");
        uint256 tokenId = addressToProfileId[msg.sender];
        
        profiles[tokenId].poaps.push(poapAddress);
        emit POAPAdded(tokenId, poapAddress);
    }

    function updateProfile(
        string memory bio,
        string[] memory skills
    ) public {
        require(hasProfile[msg.sender], "Profile does not exist");
        uint256 tokenId = addressToProfileId[msg.sender];
        
        profiles[tokenId].bio = bio;
        profiles[tokenId].skills = skills;
        
        emit ProfileUpdated(tokenId);
    }

    function getProfile(uint256 tokenId) public view returns (Profile memory) {
        require(_exists(tokenId), "Profile does not exist");
        return profiles[tokenId];
    }

    function getProfileByAddress(address user) public view returns (Profile memory) {
        require(hasProfile[user], "Profile does not exist");
        return profiles[addressToProfileId[user]];
    }

    // Override transfer functions to make the token soulbound
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        revert("ProfileNFT: Transfer not allowed - Token is soulbound");
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        revert("ProfileNFT: Transfer not allowed - Token is soulbound");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        revert("ProfileNFT: Transfer not allowed - Token is soulbound");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        revert("ProfileNFT: Transfer not allowed - Token is soulbound");
    }
}

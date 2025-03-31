// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../lib/openzeppelin/Counters.sol";

contract UserProfile is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _profileIds;

    // Mapping from address to profile ID
    mapping(address => uint256) public addressToProfile;

    // Mapping from profile ID to profile data
    mapping(uint256 => Profile) public profiles;

    // Struct to store badge data
    struct Badge {
        string name;
        string description;
        uint256 eventId;
        uint256 timestamp;
        string ipfsHash; // For badge image/metadata
    }

    // Struct to store POAP data
    struct Poap {
        string name;
        string description;
        uint256 eventId;
        uint256 timestamp;
        string ipfsHash; // For POAP image/metadata
    }

    // Struct to store user profile data
    struct Profile {
        string name;
        string bio;
        string ipfsHash;
        string[] skills; // Simple array of skill names
        uint256[] skillLevels; // Corresponding skill levels
        Badge[] badges; // Array of badges earned
        Poap[] poaps; // Array of POAPs earned
        bool active;
        uint256 lastUpdated;
    }

    // Events
    event ProfileCreated(uint256 indexed profileId, address indexed user, string name);
    event SkillAdded(uint256 indexed profileId, string skill, uint256 level);
    event ProfileUpdated(uint256 indexed profileId, string name, string bio);
    event BadgeAdded(uint256 indexed profileId, string badgeName, uint256 eventId);
    event PoapAdded(uint256 indexed profileId, string poapName, uint256 eventId);

    constructor() ERC721("UserProfile", "UPROF") Ownable(msg.sender) {}

    /**
     * @dev Create a new profile when user connects wallet
     */
    function createProfile(string calldata name, string calldata bio) public returns (uint256) {
        require(addressToProfile[msg.sender] == 0, "Profile already exists");
        
        _profileIds.increment();
        uint256 newProfileId = _profileIds.current();
        
        // Mint NFT to user's address
        _mint(msg.sender, newProfileId);
        
        // Create profile data
        Profile memory newProfile = Profile(
            name,
            bio,
            "",
            new string[](0),
            new uint256[](0),
            new Badge[](0),
            new Poap[](0),
            true,
            block.timestamp
        );
        
        profiles[newProfileId] = newProfile;
        addressToProfile[msg.sender] = newProfileId;
        
        emit ProfileCreated(newProfileId, msg.sender, name);
        return newProfileId;
    }

    /**
     * @dev Add a skill to user's profile
     */
    function addSkill(string calldata skill, uint256 level) public {
        uint256 profileId = addressToProfile[msg.sender];
        require(profileId > 0, "Profile not found");
        
        Profile storage profile = profiles[profileId];
        profile.skills.push(skill);
        profile.skillLevels.push(level);
        profile.lastUpdated = block.timestamp;
        
        emit SkillAdded(profileId, skill, level);
    }

    /**
     * @dev Add a badge to user's profile
     */
    function addBadge(
        string calldata name,
        string calldata description,
        uint256 eventId,
        string calldata ipfsHash
    ) public {
        uint256 profileId = addressToProfile[msg.sender];
        require(profileId > 0, "Profile not found");
        
        Profile storage profile = profiles[profileId];
        
        Badge memory newBadge = Badge({
            name: name,
            description: description,
            eventId: eventId,
            timestamp: block.timestamp,
            ipfsHash: ipfsHash
        });
        
        profile.badges.push(newBadge);
        profile.lastUpdated = block.timestamp;
        
        emit BadgeAdded(profileId, name, eventId);
    }

    /**
     * @dev Add a POAP to user's profile
     */
    function addPoap(
        string calldata name,
        string calldata description,
        uint256 eventId,
        string calldata ipfsHash
    ) public {
        uint256 profileId = addressToProfile[msg.sender];
        require(profileId > 0, "Profile not found");
        
        Profile storage profile = profiles[profileId];
        
        Poap memory newPoap = Poap({
            name: name,
            description: description,
            eventId: eventId,
            timestamp: block.timestamp,
            ipfsHash: ipfsHash
        });
        
        profile.poaps.push(newPoap);
        profile.lastUpdated = block.timestamp;
        
        emit PoapAdded(profileId, name, eventId);
    }

    /**
     * @dev Update profile information
     */
    function updateProfile(string calldata name, string calldata bio) public {
        uint256 profileId = addressToProfile[msg.sender];
        require(profileId > 0, "Profile not found");
        
        Profile storage profile = profiles[profileId];
        profile.name = name;
        profile.bio = bio;
        profile.lastUpdated = block.timestamp;
        
        emit ProfileUpdated(profileId, name, bio);
    }

    /**
     * @dev Check if user has a skill with the required level
     */
    function hasSkillWithLevel(
        uint256 profileId,
        string memory skillName,
        uint256 requiredLevel
    ) public view returns (bool) {
        Profile storage profile = profiles[profileId];
        
        for (uint256 i = 0; i < profile.skills.length; i++) {
            if (keccak256(bytes(profile.skills[i])) == keccak256(bytes(skillName))) {
                return profile.skillLevels[i] >= requiredLevel;
            }
        }
        
        return false;
    }

    /**
     * @dev Check if user has a badge from a specific event
     */
    function hasBadgeFromEvent(uint256 profileId, uint256 eventId) public view returns (bool) {
        Profile storage profile = profiles[profileId];
        
        for (uint256 i = 0; i < profile.badges.length; i++) {
            if (profile.badges[i].eventId == eventId) {
                return true;
            }
        }
        
        return false;
    }

    /**
     * @dev Check if user has a POAP from a specific event
     */
    function hasPoapFromEvent(uint256 profileId, uint256 eventId) public view returns (bool) {
        Profile storage profile = profiles[profileId];
        
        for (uint256 i = 0; i < profile.poaps.length; i++) {
            if (profile.poaps[i].eventId == eventId) {
                return true;
            }
        }
        
        return false;
    }

    /**
     * @dev Get user's profile data
     */
    function getProfile(uint256 profileId) public view returns (
        string memory name,
        string memory bio,
        string memory ipfsHash,
        string[] memory skills,
        uint256[] memory skillLevels,
        Badge[] memory badges,
        Poap[] memory poaps,
        bool active,
        uint256 lastUpdated
    ) {
        Profile storage profile = profiles[profileId];
        return (
            profile.name,
            profile.bio,
            profile.ipfsHash,
            profile.skills,
            profile.skillLevels,
            profile.badges,
            profile.poaps,
            profile.active,
            profile.lastUpdated
        );
    }

    /**
     * @dev Override transfer functions to make badges and POAPs soulbound
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        // Allow transfer of profile NFT
        if (tokenId == addressToProfile[from]) {
            super._transfer(from, to, tokenId);
            addressToProfile[to] = tokenId;
            addressToProfile[from] = 0;
        } else {
            // Prevent transfer of badges and POAPs
            revert("Badges and POAPs are soulbound");
        }
    }
} 
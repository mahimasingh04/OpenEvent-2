// contracts/TicketNFT.sol (ERC-1155 for batch minting)
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./EventRegistration.sol";
import "./UserProfile.sol";

contract TicketNFT is ERC1155 {
    address public eventContract; // Only EventContract can mint
    EventRegistration public eventRegistration;
    UserProfile public userProfile;

    // Mapping to store event criteria verification status
    mapping(uint256 => mapping(address => bool)) public criteriaVerified;

    constructor(
        address _eventRegistration,
        address _userProfile
    ) ERC1155("ipfs://ticket-metadata/{id}.json") {
        eventContract = msg.sender;
        eventRegistration = EventRegistration(_eventRegistration);
        userProfile = UserProfile(_userProfile);
    }

    /**
     * @dev Verify user's eligibility based on profile criteria
     */
    function verifyUserEligibility(
        uint256 eventId,
        address user
    ) external returns (bool) {
        require(msg.sender == eventContract, "Only EventContract");
        
        // Get user's profile ID
        uint256 userProfileId = userProfile.addressToProfile(user);
        require(userProfileId > 0, "User profile not found");

        // Get event details
        (
            ,,,,,,,,,,
            string[] memory requiredSkills,
            uint256[] memory requiredSkillLevels,
            uint256[] memory requiredPoapEventIds
        ) = eventRegistration.events(eventId);

        // Check if user has required skills at required levels
        for (uint256 i = 0; i < requiredSkills.length; i++) {
            require(
                userProfile.hasSkillWithLevel(userProfileId, requiredSkills[i], requiredSkillLevels[i]),
                "User does not meet skill requirements"
            );
        }

        // Check if user has required POAPs
        for (uint256 i = 0; i < requiredPoapEventIds.length; i++) {
            require(
                eventRegistration.hasPoapForEvent(requiredPoapEventIds[i], user),
                "User does not have required POAP"
            );
        }

        // Mark criteria as verified for this user and event
        criteriaVerified[eventId][user] = true;
        return true;
    }

    function mint(address attendee, uint256 eventId) external {
        require(msg.sender == eventContract, "Only EventContract");
        
        // Check if attendee is registered for the event
        require(eventRegistration.isRegistered(eventId, attendee), "Attendee not registered for this event");
        
        // Check if event is active
        (,,,,,,bool active) = eventRegistration.events(eventId);
        require(active, "Event is not active");
        
        // Check if event has not ended
        (,,,,uint256 ending_date,,) = eventRegistration.events(eventId);
        require(block.timestamp < ending_date, "Event has ended");

        // Check if user's criteria have been verified
        require(criteriaVerified[eventId][attendee], "User criteria not verified");
        
        _mint(attendee, eventId, 1, ""); // Mint 1 ticket for the event
    }

    /**
     * @dev Check if user's criteria have been verified for an event
     */
    function isCriteriaVerified(uint256 eventId, address user) external view returns (bool) {
        return criteriaVerified[eventId][user];
    }
}
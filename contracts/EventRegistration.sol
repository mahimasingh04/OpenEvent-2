// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../lib/openzeppelin/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./TicketNFT.sol";
import "./UserProfile.sol";
/**
 * @title EventRegistration
 * @dev Contract for managing event registrations and issuing NFT tickets
 */
contract EventRegistration is  ERC721Enumerable, Ownable, AutomationCompatible, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Staking configuration
    uint256 public constant MINIMUM_STAKE = 0.1 ether; // Minimum stake required to create an event
    mapping(uint256 => uint256) public eventStakes; // Mapping from eventId to stake amount
    mapping(uint256 => address) public eventStakers; // Mapping from eventId to staker address
    mapping(uint256 => bool) public stakesReleased; // Mapping to track if stakes have been released

    // Event struct to store event information
    struct Event {
        uint256 eventId;
        string name;
        uint256 ticketPrice;
        uint256 totalTickets;
        uint256 ticketsSold;
        uint256 starting_date;
        uint256 ending_date;
        bool active;
        bool stakeReleased;
        // Simplified criteria
        string[] requiredSkills;
        uint256[] requiredSkillLevels;
        uint256[] requiredPoapEventIds; // Array of event IDs for required POAPs
    }

    // Mapping from eventId to Event
    mapping(uint256 => Event) public events;
    
    // Mapping from tokenId to eventId
    mapping(uint256 => uint256) public ticketToEvent;

    //mapping event id to no of attendees
    mapping(uint => address[]) eventAttendeesMapping;

    mapping(address => uint[]) participatedEventMapping;

    // Counter for event IDs
    Counters.Counter private _eventIds;

    // Mapping to track if an attendee has received a POAP for an event
    mapping(uint256 => mapping(address => bool)) public hasReceivedPoap;

    // POAP token ID counter
    Counters.Counter private _poapTokenIds;

    // TicketNFT contract instance
    TicketNFT public ticketNFT;
    
    // UserProfile contract instance
    UserProfile public userProfile;

    

    // Events
    event EventCreated(uint256 eventId, string name, uint256 ticketPrice, uint256 totalTickets, uint256 eventDate);
    event TicketPurchased(uint256 eventId, address buyer, uint256 tokenId);
    event EventCancelled(uint256 eventId);
    event AttendeeRegistered(uint256 eventId, address attendee, uint256 registrationTime);
    event PoapMinted(uint256 eventId, address attendee, uint256 poapTokenId);
    event StakeDeposited(uint256 eventId, address organizer, uint256 amount);
    event StakeReleased(uint256 eventId, address organizer, uint256 amount);

       constructor(
        address _ticketNFT, 
        address _userProfile
    ) ERC721("EventTicket", "EVTX") Ownable(msg.sender) {
        ticketNFT = TicketNFT(_ticketNFT);
        userProfile = UserProfile(_userProfile);
    }

    /**
     * @dev Creates a new event with staking requirement and skill requirements
     */
    function createEvent(
        string calldata name,
        uint256 ticketPrice,
        uint256 totalTickets,
        uint256 starting_date,
        uint256 ending_date,
        string[] calldata _requiredSkills,
        uint256[] calldata _requiredSkillLevels,
        uint256[] calldata _requiredPoapEventIds
    ) public payable nonReentrant returns(uint eventid) {
        require(msg.value >= MINIMUM_STAKE, "Insufficient stake amount");
        require(_requiredSkills.length == _requiredSkillLevels.length, "Skills and levels length mismatch");
        
        _eventIds.increment();
        uint256 newEventId = _eventIds.current();

        Event memory currentEvent = Event(
            newEventId,
            name,
            ticketPrice,
            totalTickets,
            0,
            starting_date,
            ending_date,
            true,
            false,
            _requiredSkills,
            _requiredSkillLevels,
            _requiredPoapEventIds
        );
           
        events[newEventId] = currentEvent;
        eventStakes[newEventId] = msg.value;
        eventStakers[newEventId] = msg.sender;
        
        emit EventCreated(newEventId, name, ticketPrice, totalTickets, starting_date);
        emit StakeDeposited(newEventId, msg.sender, msg.value);

        return newEventId;
    }
     

     
    /**
     * @dev Allows users to purchase tickets
     */
    function purchaseTicket(uint256 eventId) public payable {
        Event storage eventDetails = events[eventId];
        
        require(eventDetails.active, "Event is not active");
        require(eventDetails.ticketsSold < eventDetails.totalTickets, "Event is sold out");
        require(msg.value >= eventDetails.ticketPrice, "Insufficient payment");
        
        // Mint a new NFT ticket
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(msg.sender, newTokenId);
        
        // Update ticket mapping and event details
        ticketToEvent[newTokenId] = eventId;
        eventDetails.ticketsSold += 1;
        
        emit TicketPurchased(eventId, msg.sender, newTokenId);
    }

    /**
     * @dev Cancels an event and allows refunds
     */
    function cancelEvent(uint256 eventId) public onlyOwner {
        Event storage eventDetails = events[eventId];
        require(eventDetails.active, "Event is already inactive");
        
        eventDetails.active = false;
        emit EventCancelled(eventId);
    }

    
    /**
     * @dev Verify if an address owns a ticket for a specific event
     */
    function verifyTicket(address holder, uint256 eventId) public view returns (bool) {
        uint256 balance = balanceOf(holder);
        
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(holder, i);
            if (ticketToEvent[tokenId] == eventId) {
                return true;
            }
        }
        
        return false;
    }

    /**
     * @dev Register an attendee for an event and mint ticket if criteria are met
     */
    function registerForEvent(uint256 eventId) public payable {
        Event storage eventDetails = events[eventId];
        
        // Check if event exists and is active
        require(eventDetails.active, "Event is not active");
        
        // Check if event has started
        require(block.timestamp < eventDetails.starting_date, "Event has already started");
        
        // Check if event has ended
        require(block.timestamp < eventDetails.ending_date, "Event has ended");
        
        // Check if attendee is already registered
        require(!isRegistered(eventId, msg.sender), "Already registered for this event");
        
        // If event is paid, validate payment
        if (eventDetails.ticketPrice > 0) {
            require(msg.value >= eventDetails.ticketPrice, "Insufficient payment");
        }

        // Check if user has a profile
        uint256 userProfileId = userProfile.addressToProfile(msg.sender);
        require(userProfileId > 0, "User profile not found");

        // Check if user meets minimum reputation requirement
        (,,,,uint256 userReputation,) = userProfile.getProfile(userProfileId);
        require(userReputation >= eventDetails.minimumReputation, "User does not meet minimum reputation requirement");

        // Check if user meets minimum experience requirement
        (,,,,uint256 userExperience,) = userProfile.getProfile(userProfileId);
        require(userExperience >= eventDetails.minimumExperience, "User does not meet minimum experience requirement");
        
        // Add attendee to event's attendee list
        eventAttendeesMapping[eventId].push(msg.sender);
        
        // Add event to attendee's participated events
        participatedEventMapping[msg.sender].push(eventId);
        
        // Mint ticket NFT for the attendee
        ticketNFT.mint(msg.sender, eventId);
        
        emit AttendeeRegistered(eventId, msg.sender, block.timestamp);
    }

    /**
     * @dev Check if an address is registered for an event
     */
    function isRegistered(uint256 eventId, address attendee) public view returns (bool) {
        address[] storage attendees = eventAttendeesMapping[eventId];
        
        for (uint256 i = 0; i < attendees.length; i++) {
            if (attendees[i] == attendee) {
                return true;
            }
        }
        
        return false;
    }

    /**
     * @dev Get all events an address has registered for
     */
    function getParticipatedEvents(address attendee) public view returns (uint256[] memory) {
        return participatedEventMapping[attendee];
    }

    /**
     * @dev Override transfer functions to make POAPs soulbound (non-transferable)
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        require(!hasReceivedPoap[ticketToEvent[tokenId]][from], "POAP tokens cannot be transferred");
        super._transfer(from, to, tokenId);
    }

    /**
     * @dev Mint POAPs for all attendees of an event
     */
    function mintEventPoaps(uint256 eventId) public onlyOwner {
        Event storage eventDetails = events[eventId];
        require(!eventDetails.active, "Event must be ended to mint POAPs");
        require(block.timestamp > eventDetails.ending_date, "Event must be ended to mint POAPs");

        address[] storage attendees = eventAttendeesMapping[eventId];
        
        for (uint256 i = 0; i < attendees.length; i++) {
            address attendee = attendees[i];
            if (!hasReceivedPoap[eventId][attendee]) {
                _poapTokenIds.increment();
                uint256 newPoapTokenId = _poapTokenIds.current();
                
                // Mint POAP token
                _mint(attendee, newPoapTokenId);
                
                // Mark attendee as having received POAP
                hasReceivedPoap[eventId][attendee] = true;
                
                emit PoapMinted(eventId, attendee, newPoapTokenId);
            }
        }
    }

    /**
     * @dev Check if an attendee has received a POAP for an event
     */
    function hasPoapForEvent(uint256 eventId, address attendee) public view returns (bool) {
        return hasReceivedPoap[eventId][attendee];
    }

    /**
     * @dev Get all POAPs owned by an address
     */
    function getAttendeePoaps(address attendee) public view returns (uint256[] memory) {
        uint256[] memory participatedEvents = participatedEventMapping[attendee];
        uint256 poapCount = 0;
        
        // Count how many POAPs the attendee has
        for (uint256 i = 0; i < participatedEvents.length; i++) {
            if (hasReceivedPoap[participatedEvents[i]][attendee]) {
                poapCount++;
            }
        }
        
        // Create array of POAP token IDs
        uint256[] memory poaps = new uint256[](poapCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < participatedEvents.length; i++) {
            if (hasReceivedPoap[participatedEvents[i]][attendee]) {
                poaps[currentIndex] = participatedEvents[i];
                currentIndex++;
            }
        }
        
        return poaps;
    }

    /**
     * @dev Chainlink Automation function to check if any stakes need to be released
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override returns (bool upkeepNeeded, bytes memory performData) {
        uint256[] memory eventsToProcess = new uint256[](_eventIds.current());
        uint256 count = 0;

        for (uint256 i = 1; i <= _eventIds.current(); i++) {
            Event memory eventDetails = events[i];
            if (eventDetails.active && 
                block.timestamp > eventDetails.ending_date && 
                !eventDetails.stakeReleased && 
                !stakesReleased[i]) {
                eventsToProcess[count] = i;
                count++;
            }
        }

        if (count > 0) {
            uint256[] memory eventsToRelease = new uint256[](count);
            for (uint256 i = 0; i < count; i++) {
                eventsToRelease[i] = eventsToProcess[i];
            }
            return (true, abi.encode(eventsToRelease));
        }

        return (false, "");
    }

    /**
     * @dev Chainlink Automation function to perform upkeep
     */
    function performUpkeep(bytes calldata performData) external override {
        uint256[] memory eventsToRelease = abi.decode(performData, (uint256[]));
        
        for (uint256 i = 0; i < eventsToRelease.length; i++) {
            uint256 eventId = eventsToRelease[i];
            Event storage eventDetails = events[eventId];
            
            if (eventDetails.active && 
                block.timestamp > eventDetails.ending_date && 
                !eventDetails.stakeReleased && 
                !stakesReleased[eventId]) {
                
                // Release stake
                address staker = eventStakers[eventId];
                uint256 stakeAmount = eventStakes[eventId];
                
                eventDetails.stakeReleased = true;
                stakesReleased[eventId] = true;
                
                (bool success, ) = payable(staker).call{value: stakeAmount}("");
                require(success, "Failed to release stake");
                
                emit StakeReleased(eventId, staker, stakeAmount);
            }
        }
    }

    /**
     * @dev Manual function to release stake (fallback if Chainlink Automation fails)
     */
    function releaseStake(uint256 eventId) public nonReentrant {
        Event storage eventDetails = events[eventId];
        require(eventDetails.active, "Event is not active");
        require(block.timestamp > eventDetails.ending_date, "Event has not ended");
        require(!eventDetails.stakeReleased, "Stake already released");
        require(!stakesReleased[eventId], "Stake already released");
        require(msg.sender == eventStakers[eventId], "Only staker can release stake");

        uint256 stakeAmount = eventStakes[eventId];
        eventDetails.stakeReleased = true;
        stakesReleased[eventId] = true;

        (bool success, ) = payable(msg.sender).call{value: stakeAmount}("");
        require(success, "Failed to release stake");

        emit StakeReleased(eventId, msg.sender, stakeAmount);
    }
}






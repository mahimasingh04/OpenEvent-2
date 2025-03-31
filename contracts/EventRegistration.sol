
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../lib/openzeppelin/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
/**
 * @title EventRegistration
 * @dev Contract for managing event registrations and issuing NFT tickets
 */
contract EventRegistration is  ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Event struct to store event information
    struct Event {
        uint256 eventId;
        string name;
        uint256 ticketPrice;
        uint256 totalTickets;
        uint256 ticketsSold;
        uint256 eventDate;
        bool active;
    }

    // Mapping from eventId to Event
    mapping(uint256 => Event) public events;
    
    // Mapping from tokenId to eventId
    mapping(uint256 => uint256) public ticketToEvent;

    // Counter for event IDs
    Counters.Counter private _eventIds;

    // Events
    event EventCreated(uint256 eventId, string name, uint256 ticketPrice, uint256 totalTickets, uint256 eventDate);
    event TicketPurchased(uint256 eventId, address buyer, uint256 tokenId);
    event EventCancelled(uint256 eventId);

       constructor() ERC721("EventTicket", "EVTX") Ownable(msg.sender){}

    /**
     * @dev Creates a new event
     */
    function createEvent(
        string memory name,
        uint256 ticketPrice,
        uint256 totalTickets,
        uint256 eventDate
    ) public onlyOwner {
        _eventIds.increment();
        uint256 newEventId = _eventIds.current();
        
        events[newEventId] = Event({
            eventId: newEventId,
            name: name,
            ticketPrice: ticketPrice,
            totalTickets: totalTickets,
            ticketsSold: 0,
            eventDate: eventDate,
            active: true
        });
        
        emit EventCreated(newEventId, name, ticketPrice, totalTickets, eventDate);
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
     * @dev Returns an event's details
     */
    function getEvent(uint256 eventId) public view returns (
        string memory name,
        uint256 ticketPrice,
        uint256 totalTickets,
        uint256 ticketsSold,
        uint256 eventDate,
        bool active
    ) {
        Event storage eventDetails = events[eventId];
        return (
            eventDetails.name,
            eventDetails.ticketPrice,
            eventDetails.totalTickets,
            eventDetails.ticketsSold,
            eventDetails.eventDate,
            eventDetails.active
        );
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
}

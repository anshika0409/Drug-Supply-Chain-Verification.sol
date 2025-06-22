// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Drug Supply Chain Verification
 * @dev Smart contract for tracking pharmaceutical products through the supply chain
 * @author Drug Supply Chain Verification Team
 */
contract Project {
    
    // Struct to represent a drug batch
    struct DrugBatch {
        uint256 batchId;
        string drugName;
        string manufacturer;
        uint256 manufacturingDate;
        uint256 expiryDate;
        uint256 quantity;
        address currentOwner;
        bool isActive;
        string[] supplyChainHistory;
        mapping(address => bool) authorizedHandlers;
    }
    
    // Struct for supply chain participants
    struct Participant {
        address participantAddress;
        string name;
        string role; // "Manufacturer", "Distributor", "Pharmacy", "Hospital"
        bool isActive;
        uint256 registrationDate;
    }
    
    // State variables
    mapping(uint256 => DrugBatch) public drugBatches;
    mapping(address => Participant) public participants;
    mapping(address => bool) public authorizedParticipants;
    
    uint256 public batchCounter;
    address public owner;
    
    // Events
    event BatchCreated(uint256 indexed batchId, string drugName, address indexed manufacturer);
    event OwnershipTransferred(uint256 indexed batchId, address indexed from, address indexed to);
    event ParticipantRegistered(address indexed participant, string name, string role);
    event BatchStatusUpdated(uint256 indexed batchId, string status);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can perform this action");
        _;
    }
    
    modifier onlyAuthorizedParticipant() {
        require(authorizedParticipants[msg.sender], "Not an authorized participant");
        _;
    }
    
    modifier validBatch(uint256 _batchId) {
        require(_batchId > 0 && _batchId <= batchCounter, "Invalid batch ID");
        require(drugBatches[_batchId].isActive, "Batch is not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        batchCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Register a new participant in the supply chain
     * @param _participantAddress Address of the participant
     * @param _name Name of the participant
     * @param _role Role of the participant (Manufacturer, Distributor, Pharmacy, Hospital)
     */
    function registerParticipant(
        address _participantAddress,
        string memory _name,
        string memory _role
    ) public onlyOwner {
        require(_participantAddress != address(0), "Invalid participant address");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_role).length > 0, "Role cannot be empty");
        require(!authorizedParticipants[_participantAddress], "Participant already registered");
        
        participants[_participantAddress] = Participant({
            participantAddress: _participantAddress,
            name: _name,
            role: _role,
            isActive: true,
            registrationDate: block.timestamp
        });
        
        authorizedParticipants[_participantAddress] = true;
        
        emit ParticipantRegistered(_participantAddress, _name, _role);
    }
    
    /**
     * @dev Core Function 2: Create a new drug batch and add it to the supply chain
     * @param _drugName Name of the drug
     * @param _manufacturer Manufacturer name
     * @param _manufacturingDate Manufacturing timestamp
     * @param _expiryDate Expiry timestamp
     * @param _quantity Quantity of drugs in the batch
     */
    function createDrugBatch(
        string memory _drugName,
        string memory _manufacturer,
        uint256 _manufacturingDate,
        uint256 _expiryDate,
        uint256 _quantity
    ) public onlyAuthorizedParticipant returns (uint256) {
        require(bytes(_drugName).length > 0, "Drug name cannot be empty");
        require(bytes(_manufacturer).length > 0, "Manufacturer cannot be empty");
        require(_expiryDate > _manufacturingDate, "Expiry date must be after manufacturing date");
        require(_expiryDate > block.timestamp, "Drug batch already expired");
        require(_quantity > 0, "Quantity must be greater than 0");
        
        batchCounter++;
        
        DrugBatch storage newBatch = drugBatches[batchCounter];
        newBatch.batchId = batchCounter;
        newBatch.drugName = _drugName;
        newBatch.manufacturer = _manufacturer;
        newBatch.manufacturingDate = _manufacturingDate;
        newBatch.expiryDate = _expiryDate;
        newBatch.quantity = _quantity;
        newBatch.currentOwner = msg.sender;
        newBatch.isActive = true;
        
        // Initialize supply chain history
        string memory initialEntry = string(abi.encodePacked(
            "Created by: ", _manufacturer, 
            " at ", _uint2str(block.timestamp)
        ));
        newBatch.supplyChainHistory.push(initialEntry);
        
        // Authorize the creator to handle this batch
        newBatch.authorizedHandlers[msg.sender] = true;
        
        emit BatchCreated(batchCounter, _drugName, msg.sender);
        emit BatchStatusUpdated(batchCounter, "Created");
        
        return batchCounter;
    }
    
    /**
     * @dev Core Function 3: Transfer ownership of a drug batch through the supply chain
     * @param _batchId ID of the drug batch
     * @param _newOwner Address of the new owner
     * @param _transferNote Note describing the transfer
     */
    function transferBatchOwnership(
        uint256 _batchId,
        address _newOwner,
        string memory _transferNote
    ) public validBatch(_batchId) onlyAuthorizedParticipant {
        DrugBatch storage batch = drugBatches[_batchId];
        
        require(batch.currentOwner == msg.sender, "Only current owner can transfer ownership");
        require(_newOwner != address(0), "Invalid new owner address");
        require(authorizedParticipants[_newOwner], "New owner must be authorized participant");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");
        require(block.timestamp < batch.expiryDate, "Cannot transfer expired batch");
        
        address previousOwner = batch.currentOwner;
        batch.currentOwner = _newOwner;
        batch.authorizedHandlers[_newOwner] = true;
        
        // Add transfer to supply chain history
        string memory transferEntry = string(abi.encodePacked(
            "Transferred from: ", participants[previousOwner].name,
            " to: ", participants[_newOwner].name,
            " at ", _uint2str(block.timestamp),
            " - ", _transferNote
        ));
        batch.supplyChainHistory.push(transferEntry);
        
        emit OwnershipTransferred(_batchId, previousOwner, _newOwner);
        emit BatchStatusUpdated(_batchId, "Transferred");
    }
    
    /**
     * @dev Get complete supply chain history for a drug batch
     * @param _batchId ID of the drug batch
     * @return Array of supply chain history entries
     */
    function getSupplyChainHistory(uint256 _batchId) 
        public view validBatch(_batchId) returns (string[] memory) {
        return drugBatches[_batchId].supplyChainHistory;
    }
    
    /**
     * @dev Get basic information about a drug batch
     * @param _batchId ID of the drug batch
     * @return Basic batch information
     */
    function getBatchInfo(uint256 _batchId) 
        public view validBatch(_batchId) 
        returns (
            string memory drugName,
            string memory manufacturer,
            uint256 manufacturingDate,
            uint256 expiryDate,
            uint256 quantity,
            address currentOwner,
            bool isActive
        ) {
        DrugBatch storage batch = drugBatches[_batchId];
        return (
            batch.drugName,
            batch.manufacturer,
            batch.manufacturingDate,
            batch.expiryDate,
            batch.quantity,
            batch.currentOwner,
            batch.isActive
        );
    }
    
    /**
     * @dev Verify if a batch is authentic and not expired
     * @param _batchId ID of the drug batch
     * @return Whether the batch is valid and authentic
     */
    function verifyBatchAuthenticity(uint256 _batchId) 
        public view returns (bool) {
        if (_batchId == 0 || _batchId > batchCounter) {
            return false;
        }
        
        DrugBatch storage batch = drugBatches[_batchId];
        return (batch.isActive && block.timestamp < batch.expiryDate);
    }
    
    /**
     * @dev Emergency function to deactivate a batch (e.g., for recalls)
     * @param _batchId ID of the drug batch
     * @param _reason Reason for deactivation
     */
    function deactivateBatch(uint256 _batchId, string memory _reason) 
        public onlyOwner validBatch(_batchId) {
        drugBatches[_batchId].isActive = false;
        
        string memory deactivationEntry = string(abi.encodePacked(
            "DEACTIVATED at ", _uint2str(block.timestamp),
            " - Reason: ", _reason
        ));
        drugBatches[_batchId].supplyChainHistory.push(deactivationEntry);
        
        emit BatchStatusUpdated(_batchId, "Deactivated");
    }
    
    /**
     * @dev Utility function to convert uint to string
     * @param _i Integer to convert
     * @return String representation of the integer
     */
    function _uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
    
    /**
     * @dev Get total number of batches created
     * @return Total batch count
     */
    function getTotalBatches() public view returns (uint256) {
        return batchCounter;
    }
    
    /**
     * @dev Check if an address is an authorized participant
     * @param _participant Address to check
     * @return Whether the address is authorized
     */
    function isAuthorizedParticipant(address _participant) public view returns (bool) {
        return authorizedParticipants[_participant];
    }
}

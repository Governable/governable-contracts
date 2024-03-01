pragma solidity 0.8.19;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";


/// @dev Deployed on L1
contract GovernableVaultDemo is IWormholeReceiver {
    IWormholeRelayer public immutable wormholeRelayer;

    address immutable owner;
    address immutable governance;
    uint256 immutable governanceSourceChain;

    // Errors
    error UnauthorizedRelayer();
    error InvalidRelayer();
    error InvalidGovernance();
    error OnlyOwner();
    error InvalidSourceChain();

    // Events
    event GovernableProposalPassed();

    constructor(address _wormholeRelayer, address _governance, uint16 _governanceSourceChain) {
        if (_wormholeRelayer == address(0)) {
            revert InvalidRelayer();
        }  
        if (_governance == address(0)) {
            revert InvalidGovernance();
        }  
        owner = msg.sender;
        governance = _governance;
        governanceSourceChain = _governanceSourceChain;
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
    }

    modifier onlyRelayer() {
        if(msg.sender != address(wormholeRelayer)) {
            revert UnauthorizedRelayer();
        }
        _;
    }

    modifier onlyGovernanceChain(uint256 sourceChain) {
        if (sourceChain != governanceSourceChain) {
            revert InvalidSourceChain();
        }
        _;
    }
    
    modifier onlyOwner() {
        if(msg.sender != owner) {
            revert OnlyOwner();
        }
        _;
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32, // address that called 'sendPayloadToEvm'
        uint16 sourceChain,
        bytes32 // unique identifier of delivery
    ) public payable override onlyRelayer onlyGovernanceChain(sourceChain) {

        // Parse the payload and do the corresponding actions!
        (string memory greeting, address sender) = abi.decode(payload, (string, address));
        // logic goes here

        emit GovernableProposalPassed();

    }
}

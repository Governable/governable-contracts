pragma solidity 0.8.19;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";


/// @dev Deployed on L1
contract GovernableVault is IWormholeReceiver {
    IWormholeRelayer public immutable wormholeRelayer;

    address immutable owner;
    address governance;
    uint16 immutable governanceSourceChain;

    // Errors
    error UnauthorizedRelayer();
    error InvalidRelayer();
    error InvalidGovernance();
    error OnlyOwner();
    error InvalidSourceChain();

    // Events
    event GovernableProposalExecuted(uint256 proposalId);

    constructor(address _wormholeRelayer, uint16 _governanceSourceChain) {
        if (_wormholeRelayer == address(0)) {
            revert InvalidRelayer();
        }
        owner = msg.sender;
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
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 // unique identifier of delivery
    ) public payable override onlyRelayer onlyGovernanceChain(sourceChain) {
        require(address(uint160(uint256(sourceAddress))) == governance, "Invalid governance address");
        // Parse the payload and do the corresponding actions!
        (uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory targetCallDatas) = abi.decode(payload, (uint256, address[], uint256[], bytes[]));
        
        for(uint i = 0; i < targets.length; i++) {
            (bool success, ) = targets[i].call{value: values[i]}(targetCallDatas[i]);
            require(success, "Call failed");
        }

        emit GovernableProposalExecuted(proposalId);
    }

    function setGovernance(address _governance) public onlyOwner {
        governance = _governance;
    }

    receive() external payable {}
}

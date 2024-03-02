// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./GovernorInterfaces.sol";
import {BrevisApp} from "brevis/BrevisApp.sol";
import {GovernableRelayer} from "./GovernableRelayer.sol";

// Based on https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorBravoDelegate.sol

contract Governor is GovernorStorage, GovernorEvents, BrevisApp, GovernableRelayer {

    /// @notice The name of this contract
    string public constant name = "Governor";

    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    uint public constant quorumVotes = 1000;

    /// @notice The maximum number of actions that can be included in a proposal
    uint public constant proposalMaxOperations = 10; // 10 actions

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

    /**
      * @param token The address of the voting token
      * @param votingPeriod_ The initial voting period
      * @param votingDelay_ The initial voting delay
      * @param proposalThreshold_ The initial proposal threshold
      */
    constructor(address token, uint votingPeriod_, uint votingDelay_, uint proposalThreshold_, IBrevisProof brevisProof, IBrevisRequest brevisRequest, uint256 _mappingSlotNumber, address _wormholeRelayer, uint16 _targetChain, address _vault) BrevisApp(brevisProof) GovernableRelayer(_wormholeRelayer, _targetChain, _vault) {
        require(token != address(0), "GovernorBravo::initialize: invalid token address");

        govToken = token;
        votingPeriod = votingPeriod_;
        votingDelay = votingDelay_;
        proposalThreshold = proposalThreshold_;
        BREVIS_REQUEST = brevisRequest;
        mappingSlotNumber = _mappingSlotNumber;
    }

    /**
      * @notice Function used to propose a new proposal. Sender must have delegates above the proposal threshold
      * @param targets Target addresses for proposal calls
      * @param values Eth values for proposal calls
      * @param signatures Function signatures for proposal calls
      * @param calldatas Calldatas for proposal calls
      * @param description String description of the proposal
      * @return Proposal id of new proposal
      */
    function propose(address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas, string memory description, uint256 l1CheckpointBlock) public returns (uint) {
        // Allow addresses above proposal threshold and whitelisted addresses to propose
        // require(comp.getPriorVotes(msg.sender, sub256(block.number, 1)) > proposalThreshold || isWhitelisted(msg.sender), "GovernorBravo::propose: proposer votes below proposal threshold");
        {
            require(targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length, "GovernorBravo::propose: proposal function information arity mismatch");
            require(targets.length != 0, "GovernorBravo::propose: must provide actions");
            require(targets.length <= proposalMaxOperations, "GovernorBravo::propose: too many actions");

            uint latestProposalId = latestProposalIds[msg.sender];
            if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(latestProposalId);
            require(proposersLatestProposalState != ProposalState.Active, "GovernorBravo::propose: one live proposal per proposer, found an already active proposal");
            require(proposersLatestProposalState != ProposalState.Pending, "GovernorBravo::propose: one live proposal per proposer, found an already pending proposal");
            }
        }

        uint startBlock = add256(block.number, votingDelay);
        uint endBlock = add256(startBlock, votingPeriod);

        for(uint256 i = 0; i < targets.length; i++) {
            if(bytes(signatures[i]).length != 0) {
                calldatas[i] = abi.encodeWithSignature(signatures[i], calldatas[i]);
            }
        }

        proposalCount++;
        uint newProposalID = proposalCount;
        Proposal storage newProposal = proposals[newProposalID];
        // This should never happen but add a check in case.
        require(newProposal.id == 0, "GovernorBravo::propose: ProposalID collsion");
        newProposal.id = newProposalID;
        newProposal.proposer = msg.sender;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.abstainVotes = 0;
        newProposal.canceled = false;
        newProposal.executed = false;
        newProposal.l1CheckpointBlock = l1CheckpointBlock;

        latestProposalIds[newProposal.proposer] = newProposal.id;
        blockToProposalId[l1CheckpointBlock] = newProposal.id; // Checkpointing block to proposalId

        emit ProposalCreated(newProposal.id, msg.sender, targets, values, signatures, calldatas, startBlock, endBlock, description);
        return newProposal.id;
    }

    /**
      * @notice Executes a queued proposal if eta has passed
      * @param proposalId The id of the proposal to execute
      */
    function execute(uint proposalId) external payable {
        require(state(proposalId) == ProposalState.Queued || state(proposalId) == ProposalState.Succeeded, "GovernorBravo::execute: proposal can only be executed if it is queued");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        _executeCrosschainProposal(proposalId, proposal.targets, proposal.values, proposal.calldatas);
        emit ProposalExecuted(proposalId);
    }

    /**
      * @notice Cancels a proposal only if sender is the proposer, or proposer delegates dropped below proposal threshold
      * @param proposalId The id of the proposal to cancel
      */
    function cancel(uint proposalId) external {
        require(state(proposalId) != ProposalState.Executed, "GovernorBravo::cancel: cannot cancel executed proposal");

        Proposal storage proposal = proposals[proposalId];

        // Proposer can cancel
        require(msg.sender == proposal.proposer, "Not proposer");

        proposal.canceled = true;

        emit ProposalCanceled(proposalId);
    }

    /**
      * @notice Gets actions of a proposal
      * @param proposalId the id of the proposal
      * @return targets of the proposal actions
      * @return values of the proposal actions
      * @return signatures of the proposal actions
      * @return calldatas of the proposal actions
      */
    function getActions(uint proposalId) external view returns (address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas) {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    /**
      * @notice Gets the receipt for a voter on a given proposal
      * @param proposalId the id of proposal
      * @param voter The address of the voter
      * @return The voting receipt
      */
    function getReceipt(uint proposalId, address voter) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    /**
      * @notice Gets the state of a proposal
      * @param proposalId The id of the proposal
      * @return Proposal state
      */
    function state(uint proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId, "GovernorBravo::state: invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes) {
            return ProposalState.Defeated;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else {
            return ProposalState.Succeeded;
        }
    }

    /**
      * @notice Cast a vote for a proposal
      * @param proposalId The id of the proposal to vote on
      * @param support The support value for the vote. 0=against, 1=for, 2=abstain
      */
    function castVote(uint proposalId, uint8 support, bytes32 _requestId) external {
        emit VoteCast(msg.sender, proposalId, support, castVoteInternal(msg.sender, proposalId, support), "");
        BREVIS_REQUEST.sendRequest(_requestId, address(this), address(this));
    }

    // /**
    //   * @notice Internal function that caries out voting logic
    //   * @param voter The voter that is casting their vote
    //   * @param proposalId The id of the proposal to vote on
    //   * @param support The support value for the vote. 0=against, 1=for, 2=abstain
    //   * @return The number of votes cast
    //   */
    function castVoteInternal(address voter, uint proposalId, uint8 support) internal returns (uint96) {
        require(state(proposalId) == ProposalState.Active, "GovernorBravo::castVoteInternal: voting is closed");
        require(support <= 2, "GovernorBravo::castVoteInternal: invalid vote type");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "GovernorBravo::castVoteInternal: voter already voted");

        receipt.hasVoted = true;
        receipt.support = support;

        pendingVoters[proposalId].push(voter);

        return 0;
    }

    /**
     * @notice View function which returns if an account is whitelisted
     * @param account Account to check white list status of
     * @return If the account is whitelisted
     */
    function isWhitelisted(address account) public view returns (bool) {
        return (whitelistAccountExpirations[account] > block.timestamp);
    }

    /**
      * @notice Admin function for setting the voting delay
      * @param newVotingDelay new voting delay, in blocks
      */
    function _setVotingDelay(uint newVotingDelay) external {
        require(msg.sender == admin, "GovernorBravo::_setVotingDelay: admin only");
        uint oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay,votingDelay);
    }

    /**
      * @notice Admin function for setting the voting period
      * @param newVotingPeriod new voting period, in blocks
      */
    function _setVotingPeriod(uint newVotingPeriod) external {
        require(msg.sender == admin, "GovernorBravo::_setVotingPeriod: admin only");
        uint oldVotingPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
    }

    /**
      * @notice Admin function for setting the proposal threshold
      * @dev newProposalThreshold must be greater than the hardcoded min
      * @param newProposalThreshold new proposal threshold
      */
    function _setProposalThreshold(uint newProposalThreshold) external {
        require(msg.sender == admin, "GovernorBravo::_setProposalThreshold: admin only");
        uint oldProposalThreshold = proposalThreshold;
        proposalThreshold = newProposalThreshold;

        emit ProposalThresholdSet(oldProposalThreshold, proposalThreshold);
    }

    /**
     * @notice Admin function for setting the whitelist expiration as a timestamp for an account. Whitelist status allows accounts to propose without meeting threshold
     * @param account Account address to set whitelist expiration for
     * @param expiration Expiration for account whitelist status as timestamp (if now < expiration, whitelisted)
     */
    function _setWhitelistAccountExpiration(address account, uint expiration) external {
        require(msg.sender == admin || msg.sender == whitelistGuardian, "GovernorBravo::_setWhitelistAccountExpiration: admin only");
        whitelistAccountExpirations[account] = expiration;

        emit WhitelistAccountExpirationSet(account, expiration);
    }

    /**
     * @notice Admin function for setting the whitelistGuardian. WhitelistGuardian can cancel proposals from whitelisted addresses
     * @param account Account to set whitelistGuardian to (0x0 to remove whitelistGuardian)
     */
     function _setWhitelistGuardian(address account) external {
        require(msg.sender == admin, "GovernorBravo::_setWhitelistGuardian: admin only");
        address oldGuardian = whitelistGuardian;
        whitelistGuardian = account;

        emit WhitelistGuardianSet(oldGuardian, whitelistGuardian);
     }

    /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
      */
    function _setPendingAdmin(address newPendingAdmin) external {
        // Check caller = admin
        require(msg.sender == admin, "GovernorBravo:_setPendingAdmin: admin only");

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      */
    function _acceptAdmin() external {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        require(msg.sender == pendingAdmin && msg.sender != address(0), "GovernorBravo:_acceptAdmin: pending admin only");

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

    function add256(uint256 a, uint256 b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "addition overflow");
        return c;
    }

    function sub256(uint256 a, uint256 b) internal pure returns (uint) {
        require(b <= a, "subtraction underflow");
        return a - b;
    }

    function getChainIdInternal() internal view returns (uint) {
        uint chainId;
        assembly { chainId := chainid() }
        return chainId;
    }

    function handleProofResult(
        bytes32 /*_requestId*/,
        bytes32 _vkHash,
        bytes calldata _circuitOutput
    ) internal override {
        // We need to check if the verifying key that Brevis used to verify the proof generated by our circuit is indeed
        // our designated verifying key. This proves that the _circuitOutput is authentic
        require(vkHash == bytes32(0) || vkHash == _vkHash, "invalid vk");

        (uint64 blockNum, address contractAddress, bytes32 slotNumber, bytes32 value) = decodeOutput(_circuitOutput);
        uint256 proposalId = blockToProposalId[blockNum];

        require(proposalId != 0, "Invalid start block number");

        require(contractAddress == govToken, "invalid contract address");

        address[] storage pendingVotes = pendingVoters[proposalId];
        for(uint256 i = 0; i < pendingVotes.length; i++) {
            address voter = pendingVotes[i];
            if(voter != address(0) && slotNumber == keccak256(abi.encodePacked(keccak256(abi.encode(voter, mappingSlotNumber))))) {
                _finalizeVote(proposalId, voter, uint96(uint256(value)));
                delete pendingVotes[i];
                break;
            }
        }
    }

    function _finalizeVote(uint256 proposalId, address voter, uint96 votes) internal {
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        uint8 support = uint8(receipt.support);
        proposal.receipts[voter].votes = votes;

        if (support == 0) {
            proposal.againstVotes = add256(proposal.againstVotes, votes);
        } else if (support == 1) {
            proposal.forVotes = add256(proposal.forVotes, votes);
        } else if (support == 2) {
            proposal.abstainVotes = add256(proposal.abstainVotes, votes);
        }
        emit VoteFinalized(voter, proposalId, support, votes);
    }

    function finalizeVote(uint256 proposalId, address voter, uint96 votes) external {
        address[] storage pendingVotes = pendingVoters[proposalId];
        for(uint256 i = 0; i < pendingVotes.length; i++) {
            if(pendingVotes[i] == voter) {
                _finalizeVote(proposalId, voter, votes);
                delete pendingVotes[i];
                break;
            }
        }
    }

    function decodeOutput(bytes calldata o) internal pure returns (uint64, address, bytes32, bytes32) {
        uint64 blockNum = uint64(bytes8(o[0:8])); // blockNum was output as a uint64 (8 bytes)
        address contractAddress = address(bytes20(o[8:28])); // contractAddress was output as an address
        bytes32 slot = bytes32(o[28:60]); // slot was output as a bytes32
        bytes32 slotValue = bytes32(o[60:92]); // slotValue was output as a bytes32
        
        return (blockNum, contractAddress, slot, slotValue);
    }

    function setVkHash(bytes32 _vkHash) external {
        vkHash = _vkHash;
    }
}
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8;

import "src/L2Governance/Governor.sol";

contract MockGovernor is Governor {
    constructor(address token, uint votingPeriod_, uint votingDelay_, uint proposalThreshold_, IBrevisRequest brevisRequest, uint256 _mappingSlotNumber, address _wormholeRelayer, uint16 _targetChain, address _vault) Governor(token, votingPeriod_, votingDelay_, proposalThreshold_, IBrevisProof(address(0)), brevisRequest, _mappingSlotNumber, _wormholeRelayer, _targetChain, _vault) {}
    function brevisCallback(bytes32 _requestId, bytes calldata _appCircuitOutput) override external {
        handleProofResult(_requestId, bytes32(0), _appCircuitOutput);
    }
}
// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8;

import {IBrevisProof} from "brevis/IBrevisProof.sol";
import {IBrevisRequest} from "brevis/IBrevisRequest.sol";
import {IBrevisApp} from "brevis/IBrevisApp.sol";
import "brevis/Lib.sol";

contract MockBrevis is IBrevisProof, IBrevisRequest {
    bool public doCallback = true;

    function setDoCallback(bool _doCallback) external {
        doCallback = _doCallback;
    }

    bytes public appCircuitOutput;

    function setOutput(uint256 blockNumber, address contractAddress, bytes32 slot, bytes32 slotValue) external {
        appCircuitOutput = abi.encodePacked(uint64(blockNumber), contractAddress, slot, slotValue);
    }
    
    function submitProof(
        uint64 _chainId,
        bytes calldata _proofWithPubInputs,
        bool _withAppProof
    ) external returns (bytes32 _requestId) {return bytes32(0);}

    function hasProof(bytes32 _requestId) external view returns (bool) {return false;}

    // used by contract app
    function validateRequest(bytes32 _requestId, uint64 _chainId, Brevis.ExtractInfos memory _info) external view {}

    function getProofData(bytes32 _requestId) external view returns (Brevis.ProofData memory) {}

    // return appCommitHash and appVkHash
    function getProofAppData(bytes32 _requestId) external view returns (bytes32, bytes32) {return (bytes32(0), bytes32(0));}

    function sendRequest(bytes32 _requestId, address _refundee, address _callback) external payable {
        if(doCallback) IBrevisApp(_callback).brevisCallback(_requestId,appCircuitOutput);
    }
}
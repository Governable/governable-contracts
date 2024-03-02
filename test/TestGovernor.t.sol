// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8;

import {Test, Vm} from "forge-std/Test.sol";
import {MockGovernor} from "./MockGovernor.sol";
import {MockBrevis} from "./MockBrevis.sol";

contract TestGovernor is Test {
    MockGovernor public governor;
    address public tokenAddress = address(123);
    MockBrevis public brevis;
    uint256 constant MAPPING_SLOT_NUMBER = 0;

    function setUp() public {
        brevis = new MockBrevis();
        governor = new MockGovernor(tokenAddress, 100, 1, 1000, brevis, MAPPING_SLOT_NUMBER, address(0), 0, address(0));
    }

    function testVote() public {
        Vm.Wallet memory arr00 = vm.createWallet("arr00");

        uint256[] memory values = new uint256[](1);
        values[0] = 0.01 ether;

        address[] memory targets = new address[](1);
        targets[0] = arr00.addr;

        vm.prank(arr00.addr);
        uint256 proposalId = governor.propose(targets, values, new string[](1), new bytes[](1), "I would love some eth", 19341097);

        (,,,,,,,,,uint256 l1CheckpointBlock) = governor.proposals(proposalId);
        emit log_uint(l1CheckpointBlock);
        brevis.setOutput(l1CheckpointBlock, tokenAddress, keccak256(abi.encodePacked(keccak256(abi.encode(arr00.addr, MAPPING_SLOT_NUMBER)))), bytes32(uint256(1000)));

        vm.roll(block.number + 10);
        vm.prank(arr00.addr);
        governor.castVote(proposalId, 1, bytes32(uint256(2)));

        assertEq(_getVotesFor(proposalId), 1000);

        assertEq(uint8(governor.state(proposalId)), 1);

        vm.roll(block.number + 100);

        assertEq(uint8(governor.state(proposalId)), 4);

        vm.expectRevert();
        governor.execute(proposalId);
    }

    function testVote_force() public {
        brevis.setDoCallback(false);

        Vm.Wallet memory arr00 = vm.createWallet("arr00");

        uint256[] memory values = new uint256[](1);
        values[0] = 0.01 ether;

        address[] memory targets = new address[](1);
        targets[0] = arr00.addr;

        vm.prank(arr00.addr);
        uint256 proposalId = governor.propose(targets, values, new string[](1), new bytes[](1), "I would love some eth", 19341097);

        (,,,,,,,,,uint256 l1CheckpointBlock) = governor.proposals(proposalId);
        emit log_uint(l1CheckpointBlock);
        brevis.setOutput(l1CheckpointBlock, tokenAddress, keccak256(abi.encodePacked(keccak256(abi.encode(arr00.addr, MAPPING_SLOT_NUMBER)))), bytes32(uint256(1000)));

        vm.roll(block.number + 10);
        vm.prank(arr00.addr);
        governor.castVote(proposalId, 1, bytes32(uint256(2)));

        governor.finalizeVote(1, arr00.addr, 1000);

        assertEq(_getVotesFor(proposalId), 1000);
    }

    function _getVotesFor(uint256 proposalId) internal view returns (uint256 forVotes) {
        (,,,,forVotes,,,,,) = governor.proposals(proposalId);
    }
}
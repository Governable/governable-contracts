// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Governor} from "src/L2Governance/Governor.sol";
import {IBrevisRequest} from "brevis/IBrevisRequest.sol";
import {IBrevisProof} from "brevis/IBrevisProof.sol";

contract Deploy is Script {
    address graphToken = 0xc944E90C64B2c07662A292be6244BDf05Cda44a7;
    IBrevisProof brevisProof = IBrevisProof(0x7d4ed4077826Bf9BEB6232240A39db251e513e16);
    IBrevisRequest brevisRequest = IBrevisRequest(0x16ffF3b84D38779C9d9677cA1Ed2E3569d4cd667);

    function run() public {
        vm.startBroadcast();
        Governor gov = new Governor(graphToken, 100, 1, 1000, brevisProof, brevisRequest, 2, address(0), 1, address(0));

        gov.propose(new address[](1), new uint256[](1), new string[](1), new bytes[](1), "I would love some eth", 19341097);
    }
}

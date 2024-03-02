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
    address wormholeRelayer = 0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470;
    address vault = 0x60d9DCe12fAbCB6fEf7982Ec39b8f2Ae6B61B8b8; // Set the vault address prior to deploying

    function run() public {
        vm.startBroadcast();
        Governor gov = new Governor(graphToken, 25, 1, 1000, brevisProof, brevisRequest, 2, wormholeRelayer, 16, vault);
    }
}

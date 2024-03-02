// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Governor} from "src/L2Governance/Governor.sol";
import {IBrevisRequest} from "brevis/IBrevisRequest.sol";
import {IBrevisProof} from "brevis/IBrevisProof.sol";
import {GovernableVault} from "src/GovernableVault.sol";

contract Deploy is Script {
    uint16 sourceChainId = 10002; // Sepolia wormhole
    address wormholeRelayer = 0x0591C25ebd0580E0d4F27A82Fc2e24E7489CB5e0;
    function run() public {
        vm.startBroadcast();
        GovernableVault vault = new GovernableVault(wormholeRelayer, sourceChainId);
    }
}

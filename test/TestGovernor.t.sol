// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8;

import {Test, Vm} from "forge-std/Test.sol";
import {Governor} from "src/L2Governance/Governor.sol";

contract TestGovernor is Test {
    Governor public governor;

    function setUp() public {
        // governor = new Governor();
    }
}
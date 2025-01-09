// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract DeployMultiSig is Script {
    // Adresses de test
    address constant USER1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant USER2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant USER3 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    function run() external returns (MultiSigWallet) {
        address[] memory signers = new address[](3);
        signers[0] = USER1;
        signers[1] = USER2;
        signers[2] = USER3;

        vm.startBroadcast();
        MultiSigWallet wallet = new MultiSigWallet(signers, 2);
        vm.stopBroadcast();
        
        return wallet;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;
    
    address constant USER1 = address(0x4);
    address constant USER2 = address(0x5);
    address constant USER3 = address(0x6);
    address constant NON_SIGNER = address(0x7);
    
    event Deposit(address indexed sender, uint256 value);
    event SubmitTransaction(uint256 indexed txIndex, address indexed owner, address indexed to, uint256 value, bytes data);
    event ConfirmTransaction(uint256 indexed txIndex, address indexed owner);
    event RevokeConfirmation(uint256 indexed txIndex, address indexed owner);
    event ExecuteTransaction(uint256 indexed txIndex);
    event AddSigner(address indexed owner);
    event RemoveSigner(address indexed owner);

    function setUp() public {
        address[] memory signers = new address[](3);
        signers[0] = USER1;
        signers[1] = USER2;
        signers[2] = USER3;

        wallet = new MultiSigWallet(signers, 2);

        vm.deal(address(wallet), 10 ether);
    }

    function testConstructorSuccess() public view {
        assertEq(wallet.getSignerCount(), 3);
        assertEq(wallet.requiredConfirmations(), 2);
        assertTrue(wallet.isSigner(USER1));
        assertTrue(wallet.isSigner(USER2));
        assertTrue(wallet.isSigner(USER3));
    }

    function testConstructorFailInvalidSignerCount() public {
        address[] memory signers = new address[](2);
        signers[0] = USER1;
        signers[1] = USER2;

        vm.expectRevert(MultiSigWallet.NotEnoughSigners.selector);
        new MultiSigWallet(signers, 2);
    }

    function testConstructorFailDuplicateSigner() public {
        address[] memory signers = new address[](3);
        signers[0] = USER1;
        signers[1] = USER1; 
        signers[2] = USER2;

        vm.expectRevert(MultiSigWallet.DuplicateSigner.selector);
        new MultiSigWallet(signers, 2);
    }

    function testConstructorFailTooManyConfirmations() public {
        address[] memory signers = new address[](3);
        signers[0] = USER1;
        signers[1] = USER2;
        signers[2] = USER3;
        vm.expectRevert(MultiSigWallet.InvalidConfirmations.selector);
        new MultiSigWallet(signers, 4);
    }

    function testConstructorFailZeroConfirmations() public {
        address[] memory signers = new address[](3);
        signers[0] = USER1;
        signers[1] = USER2;
        signers[2] = USER3;
        vm.expectRevert(MultiSigWallet.InvalidConfirmations.selector);
        new MultiSigWallet(signers, 0);
    }

    function testSubmitTransaction() public {
        vm.prank(USER1);
        uint256 txIndex = wallet.submitTransaction(NON_SIGNER, 1 ether, "");
        
        (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations) = wallet.getTransaction(txIndex);
        
        assertEq(to, NON_SIGNER);
        assertEq(value, 1 ether);
        assertEq(data, "");
        assertFalse(executed);
        assertEq(numConfirmations, 0);
    }

    function testSubmitTransactionFailNonSigner() public {
        vm.prank(NON_SIGNER);
        vm.expectRevert(MultiSigWallet.NotSigner.selector);
        wallet.submitTransaction(NON_SIGNER, 1 ether, "");
    }

    function testConfirmTransaction() public {
        vm.prank(USER1);
        uint256 txIndex = wallet.submitTransaction(NON_SIGNER, 1 ether, "");

        vm.prank(USER1);
        wallet.confirmTransaction(txIndex);

        assertTrue(wallet.isConfirmed(txIndex, USER1));
        (,,,, uint256 numConfirmations) = wallet.getTransaction(txIndex);
        assertEq(numConfirmations, 1);
    }

    function testConfirmAndExecuteTransaction() public {
        address recipient = address(0x123);
        uint256 initialBalance = address(recipient).balance;

        vm.prank(USER1);
        uint256 txIndex = wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(USER1);
        wallet.confirmTransaction(txIndex);

        vm.prank(USER2);
        wallet.confirmTransaction(txIndex);

        (,,, bool executed,) = wallet.getTransaction(txIndex);
        assertTrue(executed);
        assertEq(address(recipient).balance - initialBalance, 1 ether);
    }

    function testConfirmNonExistentTransaction() public {
        vm.prank(USER1);
        vm.expectRevert(MultiSigWallet.TxNotExists.selector);
        wallet.confirmTransaction(999);
    }

    function testRevokeConfirmation() public {
        vm.prank(USER1);
        uint256 txIndex = wallet.submitTransaction(NON_SIGNER, 1 ether, "");

        vm.startPrank(USER1);
        wallet.confirmTransaction(txIndex);
        assertTrue(wallet.isConfirmed(txIndex, USER1));

        wallet.revokeConfirmation(txIndex);
        assertFalse(wallet.isConfirmed(txIndex, USER1));
        vm.stopPrank();
    }

    function testRevokeConfirmationFailNotConfirmed() public {
        vm.prank(USER1);
        uint256 txIndex = wallet.submitTransaction(NON_SIGNER, 1 ether, "");

        vm.prank(USER1);
        vm.expectRevert(MultiSigWallet.NotConfirmed.selector);
        wallet.revokeConfirmation(txIndex);
    }

    function testRevokeAfterExecution() public {
        vm.prank(USER1);
        uint256 txIndex = wallet.submitTransaction(NON_SIGNER, 1 ether, "");

        vm.prank(USER1);
        wallet.confirmTransaction(txIndex);
        vm.prank(USER2);
        wallet.confirmTransaction(txIndex);

        vm.prank(USER1);
        vm.expectRevert(MultiSigWallet.TxAlreadyExecuted.selector);
        wallet.revokeConfirmation(txIndex);
    }

    function testAddSigner() public {
        vm.prank(USER1);
        wallet.addSigner(NON_SIGNER);

        assertTrue(wallet.isSigner(NON_SIGNER));
        assertEq(wallet.getSignerCount(), 4);
    }

    function testAddSignerFailsForZeroAddress() public {
        vm.prank(USER1);
        vm.expectRevert(MultiSigWallet.NullAddress.selector);
        wallet.addSigner(address(0));
    }

    function testAddSignerFailsForDuplicate() public {
        vm.prank(USER1);
        vm.expectRevert(MultiSigWallet.DuplicateSigner.selector);
        wallet.addSigner(USER2);
    }

    function testRemoveSigner() public {
        vm.prank(USER1);
        wallet.addSigner(NON_SIGNER);

        vm.prank(USER1);
        wallet.removeSigner(USER2);

        assertFalse(wallet.isSigner(USER2));
        assertEq(wallet.getSignerCount(), 3);
    }

    function testRemoveSignerFailMinSigners() public {
        vm.prank(USER1);
        vm.expectRevert(MultiSigWallet.MinSignersRequired.selector);
        wallet.removeSigner(USER2);
    }

    function testRemoveSignerFailsForNonSigner() public {
        vm.prank(USER1);
        vm.expectRevert(MultiSigWallet.NotSigner.selector);
        wallet.removeSigner(NON_SIGNER);
    }

    function testRemoveLastSignerFails() public {
        vm.prank(USER1);
        wallet.addSigner(NON_SIGNER);
        
        vm.startPrank(USER1);
        wallet.removeSigner(USER2);
        vm.expectRevert(MultiSigWallet.MinSignersRequired.selector);
        wallet.removeSigner(USER3);
        vm.stopPrank();
    }

    function testAddAndRemoveMultipleSigners() public {
        address SIGNER4 = address(0x8);
        address SIGNER5 = address(0x9);
        
        vm.startPrank(USER1);
        wallet.addSigner(SIGNER4);
        wallet.addSigner(SIGNER5);
        assertEq(wallet.getSignerCount(), 5);
        
        wallet.removeSigner(SIGNER4);
        wallet.removeSigner(SIGNER5);
        assertEq(wallet.getSignerCount(), 3);
        
        vm.expectRevert(MultiSigWallet.MinSignersRequired.selector);
        wallet.removeSigner(USER2);
        vm.stopPrank();
    }

    function testGetTransaction() public {
        vm.prank(USER1);
        uint256 txIndex = wallet.submitTransaction(NON_SIGNER, 1 ether, "");

        (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations) = wallet.getTransaction(txIndex);
        
        assertEq(to, NON_SIGNER);
        assertEq(value, 1 ether);
        assertEq(data, "");
        assertFalse(executed);
        assertEq(numConfirmations, 0);
    }

    function testGetSigners() public view {
        address[] memory currentSigners = wallet.getSigners();
        assertEq(currentSigners.length, 3);
        assertEq(currentSigners[0], USER1);
        assertEq(currentSigners[1], USER2);
        assertEq(currentSigners[2], USER3);
    }

    function testReceiveEther() public {
        uint256 initialBalance = address(wallet).balance;
        uint256 amount = 1 ether;
        
        vm.deal(NON_SIGNER, amount);
        
        vm.expectEmit(true, false, false, true);
        emit Deposit(NON_SIGNER, amount);
        
        vm.prank(NON_SIGNER);
        (bool success,) = address(wallet).call{value: amount}("");
        
        assertTrue(success);
        assertEq(address(wallet).balance, initialBalance + amount);
    }
}
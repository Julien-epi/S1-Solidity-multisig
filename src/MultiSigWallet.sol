// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MultiSig Wallet
/// @author Julien
/// @notice A wallet requiring multiple signatures to execute transactions
/// @dev Implements multisig functionality without external dependencies
contract MultiSigWallet {
    /// @notice Required number of signers for the wallet
    uint256 public constant MIN_SIGNERS = 3;
    
    /// @notice Required number of confirmations to execute a transaction
    uint256 public immutable requiredConfirmations;
    
    /// @notice Array of signer addresses
    address[] public signers;
    
    /// @notice Mapping to check if an address is a signer
    mapping(address => bool) public isSigner;

    /// @notice Structure for a transaction
    /// @dev Includes all necessary fields for transaction execution
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    /// @notice Array of all transactions
    Transaction[] public transactions;

    /// @notice Mapping from tx index => signer => bool
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    // Events
    event Deposit(address indexed sender, uint256 value);
    event SubmitTransaction(uint256 indexed txIndex, address indexed owner, address indexed to, uint256 value, bytes data);
    event ConfirmTransaction(uint256 indexed txIndex, address indexed owner);
    event RevokeConfirmation(uint256 indexed txIndex, address indexed owner);
    event ExecuteTransaction(uint256 indexed txIndex);
    event AddSigner(address indexed owner);
    event RemoveSigner(address indexed owner);

    // Custom errors
    error NotSigner();
    error TxNotExists();
    error TxAlreadyExecuted();
    error TxAlreadyConfirmed();
    error NotEnoughSigners();
    error InvalidConfirmations();
    error NullAddress();
    error DuplicateSigner();
    error NotConfirmed();
    error MinSignersRequired();
    error ExecutionFailed();
    error InsufficientConfirmations();

    /// @notice Ensures caller is a signer
    modifier onlySigner() {
        if (!isSigner[msg.sender]) revert NotSigner();
        _;
    }

    /// @notice Ensures transaction exists
    modifier txExists(uint256 _txIndex) {
        if (_txIndex >= transactions.length) revert TxNotExists();
        _;
    }

    /// @notice Ensures transaction is not executed
    modifier notExecuted(uint256 _txIndex) {
        if (transactions[_txIndex].executed) revert TxAlreadyExecuted();
        _;
    }

    /// @notice Ensures transaction is not already confirmed by signer
    modifier notConfirmed(uint256 _txIndex) {
        if (isConfirmed[_txIndex][msg.sender]) revert TxAlreadyConfirmed();
        _;
    }

    /// @notice Contract constructor
    /// @param _signers Array of initial signer addresses
    /// @param _requiredConfirmations Number of required confirmations for a transaction
    constructor(address[] memory _signers, uint256 _requiredConfirmations) {
        if (_signers.length < MIN_SIGNERS) revert NotEnoughSigners();
        if (_requiredConfirmations < 2 || _requiredConfirmations > _signers.length) 
            revert InvalidConfirmations();

        for (uint256 i = 0; i < _signers.length; i++) {
            if (_signers[i] == address(0)) revert NullAddress();
            if (isSigner[_signers[i]]) revert DuplicateSigner();

            isSigner[_signers[i]] = true;
            signers.push(_signers[i]);
        }

        requiredConfirmations = _requiredConfirmations;
    }

    /// @notice Submit a new transaction
    /// @param _to Recipient address
    /// @param _value Amount of ETH to send
    /// @param _data Transaction data
    /// @return txIndex Index of submitted transaction
    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlySigner returns (uint256) {
        uint256 txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 0
        }));

        emit SubmitTransaction(txIndex, msg.sender, _to, _value, _data);
        return txIndex;
    }

    /// @notice Confirm a pending transaction
    /// @param _txIndex Transaction index
    function confirmTransaction(uint256 _txIndex)
        public
        onlySigner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(_txIndex, msg.sender);

        if (transaction.numConfirmations >= requiredConfirmations) {
            executeTransaction(_txIndex);
        }
    }

    /// @notice Execute a confirmed transaction
    /// @param _txIndex Transaction index
    function executeTransaction(uint256 _txIndex)
        internal
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        if (transaction.numConfirmations < requiredConfirmations)
            revert InsufficientConfirmations();

        transaction.executed = true;

        (bool success,) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        if (!success) revert ExecutionFailed();

        emit ExecuteTransaction(_txIndex);
    }

    /// @notice Revoke a confirmation
    /// @param _txIndex Transaction index
    function revokeConfirmation(uint256 _txIndex)
        public
        onlySigner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        if (!isConfirmed[_txIndex][msg.sender]) revert NotConfirmed();
        
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(_txIndex, msg.sender);
    }

    /// @notice Add a new signer
    /// @param _newSigner Address of new signer
    function addSigner(address _newSigner) public onlySigner {
        if (_newSigner == address(0)) revert NullAddress();
        if (isSigner[_newSigner]) revert DuplicateSigner();
        
        isSigner[_newSigner] = true;
        signers.push(_newSigner);
        
        emit AddSigner(_newSigner);
    }

    /// @notice Remove an existing signer
    /// @param _signer Address of signer to remove
    function removeSigner(address _signer) public onlySigner {
        if (!isSigner[_signer]) revert NotSigner();
        if (signers.length <= MIN_SIGNERS) revert MinSignersRequired();
        if (signers.length - 1 < requiredConfirmations) revert InvalidConfirmations();

        isSigner[_signer] = false;
        
        for (uint i = 0; i < signers.length; i++) {
            if (signers[i] == _signer) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }
        
        emit RemoveSigner(_signer);
    }

    /// @notice Get number of signers
    /// @return Number of signers
    function getSignerCount() public view returns (uint256) {
        return signers.length;
    }

    /// @notice Get list of signers
    /// @return Array of signer addresses
    function getSigners() public view returns (address[] memory) {
        return signers;
    }

    /// @notice Get number of transactions
    /// @return Number of transactions
    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    /// @notice Get transaction details
    /// @param _txIndex Transaction index
    /// @return to Recipient address
    /// @return value Transaction value
    /// @return data Transaction data
    /// @return executed Execution status
    /// @return numConfirmations Number of confirmations
    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];
        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
}
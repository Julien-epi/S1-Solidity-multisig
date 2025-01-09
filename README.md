# MultiSig Wallet

Un portefeuille multi-signatures permettant la gestion collective des fonds et des transactions.

## Prérequis

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/)

## Installation

```bash
git clone https://github.com/Julien-epi/S1-Solidity-multisig
cd multisig-wallet
forge install

# Lancer le serveur de développement
anvil

# Dans un nouveau terminal, lancer les tests:

forge test ou avec "-vvv" pour plus de détails

# Vérifier la couverture des tests:
forge coverage

cp .env.example .env

# Déployer sur anvil:

forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# CMD : 

# Creer 3 nvx wallets avec : 
cast wallet new

# Remplacer CONTRACT_ADDRESS par l'adresse de déploiement

# Vérifier les signataires
cast call CONTRACT_ADDRESS "getSigners()" --rpc-url http://localhost:8545

# Soumettre une transaction (depuis USER1)
cast send CONTRACT_ADDRESS "submitTransaction(address,uint256,bytes)" RECIPIENT_ADDRESS 1000000000000000000 0x --rpc-url http://localhost:8545 --private-key PRIVATE_KEY_USER1

# Confirmer une transaction (USER2)
cast send CONTRACT_ADDRESS "confirmTransaction(uint256)" 0 --rpc-url http://localhost:8545 --private-key PRIVATE_KEY_USER2

# Vérifier une transaction
cast call CONTRACT_ADDRESS "getTransaction(uint256)" 0 --rpc-url http://localhost:8545

# Vérifier le nombre de signataires
cast call CONTRACT_ADDRESS "getSignerCount()" --rpc-url http://localhost:8545
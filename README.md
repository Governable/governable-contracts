## Governable Contracts

This repo contains the contracts used for `Governable`. The L2 voting contract is [`Governor.sol`](src/L2Governance/Governor.sol). The L1 vault contract is [`GovernableVault.sol`](src/GovernableVault.sol). We use Foundry script for deploying on to the respective networks.

## Usage

### Build

```shell
$ yarn install
```

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Deploy

```shell
$ yarn deploy:moonbeam
```

```shell
$ yarn deploy:sepolia
```
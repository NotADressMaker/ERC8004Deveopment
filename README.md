# ERC-8004 Agent Registry Monorepo

End-to-end local development stack for ERC-8004 registries, an indexer, and a dashboard.

## Stack

- **Contracts**: Solidity + Foundry
- **Indexer/API**: Node.js + TypeScript + SQLite + Express
- **Dashboard**: Next.js (TypeScript)
- **Package Manager**: pnpm

## Requirements

- Node.js 18+
- pnpm
- Foundry

## Quickstart (Local Anvil)

```bash
pnpm install
pnpm -C contracts test
pnpm -C contracts script script/Deploy.s.sol:Deploy --broadcast --rpc-url http://127.0.0.1:8545
pnpm -C contracts script script/DemoData.s.sol:DemoData --broadcast --rpc-url http://127.0.0.1:8545
pnpm -C services/indexer dev
pnpm -C apps/dashboard dev
```

## Contracts

The deploy script writes deployment addresses to:

```
deployments/local.json
```

### Registry signing + attester controls

**Gasless EIP-712 submissions (relayer flow):**

Reputation `submitFeedbackBySig` and validation `submitValidationBySig` accept EIP-712 signatures. The relayer submits
the transaction, while the signer is recorded as the author/attester. Each signer uses a monotonically increasing
`nonces(address)` value and provides a `deadline` timestamp.

Typed data (ReputationRegistry):

```json
{
  "domain": {
    "name": "ERC8004 Reputation Registry",
    "version": "2",
    "chainId": "<chainId>",
    "verifyingContract": "<registryAddress>"
  },
  "types": {
    "Feedback": [
      { "name": "author", "type": "address" },
      { "name": "agentId", "type": "uint256" },
      { "name": "value", "type": "int256" },
      { "name": "valueDecimals", "type": "uint8" },
      { "name": "tag1", "type": "string" },
      { "name": "tag2", "type": "string" },
      { "name": "endpoint", "type": "string" },
      { "name": "feedbackURI", "type": "string" },
      { "name": "feedbackHash", "type": "bytes32" },
      { "name": "nonce", "type": "uint256" },
      { "name": "deadline", "type": "uint256" }
    ]
  },
  "primaryType": "Feedback"
}
```

Typed data (ValidationRegistry):

```json
{
  "domain": {
    "name": "ERC8004 Validation Registry",
    "version": "2",
    "chainId": "<chainId>",
    "verifyingContract": "<registryAddress>"
  },
  "types": {
    "Validation": [
      { "name": "attester", "type": "address" },
      { "name": "agentId", "type": "uint256" },
      { "name": "validationType", "type": "bytes32" },
      { "name": "proofURI", "type": "string" },
      { "name": "proofHash", "type": "bytes32" },
      { "name": "validationHash", "type": "bytes32" },
      { "name": "nonce", "type": "uint256" },
      { "name": "deadline", "type": "uint256" }
    ]
  },
  "primaryType": "Validation"
}
```

**Attester modes:**

- `OPEN` (default): anyone can submit feedback or validations.
- `ALLOWLIST`: only addresses approved by `setAllowlist(address,bool)` can submit.
- `REGISTRY`: `setAttesterRegistry(address)` points to a registry implementing `IAttesterRegistry`, which supplies
  `isAttester()` and a `weight()` (>= 1). Weight is emitted on events for indexer scoring.

**Proof formats:**

- `agentURI` and `proofURI` must be `ipfs://` or `https://` URIs with reasonable length bounds.
- `metadataHash` is stored on-chain as `keccak256(bytes(agentURI))`.
- `proofHash` is a `bytes32` commitment to the validation artifact contents or JSON payload.

## Indexer

The indexer reads `deployments/local.json`, syncs on-chain events into SQLite, and provides a REST API.

Endpoints:

- `GET /health`
- `GET /agents`
- `GET /agents/:agentId`
- `GET /agents/:agentId/feedback`
- `GET /agents/:agentId/validations`
- `GET /score` (optionally filter with `?agentId=123`)

## Validator Service

The validator service accepts validation requests, runs a verification plugin, and can submit validation responses to
the on-chain `ValidationRegistry`.

Endpoints:

- `GET /health`
- `POST /validate`

See `services/validator/README.md` for payload examples and plugin details.

## Job Board + Escrow

`JobBoardEscrow` posts jobs with off-chain job specs and on-chain commitment hashes. Payments are escrowed and released
after validator-approved proofs via `ValidationRegistry`, with optional milestone-based payouts and a dispute window.
If a dispute proposal is not accepted before the window closes, the job owner can reclaim the remaining escrow.

## Dashboard

Browse agents, reputation, and validations without a wallet. Wallet is only required for submit actions.

## Environment

Copy `.env.example` to `.env` and adjust as needed.

## GitHub Projects

2) Reputation Indexer + Scoring API (anti-sybil, trust weighting)
   - Index on-chain feedback + revocations + validation responses.
   - Maintain a reputation score that weights reviewers (allowlists, stake, identity proofs).
   - Expose `/agents`, `/agents/:id`, `/score` endpoints.
   - Why: on-chain events are composable, but scoring is usually computed off-chain for speed and flexibility.

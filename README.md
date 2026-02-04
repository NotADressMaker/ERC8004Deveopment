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

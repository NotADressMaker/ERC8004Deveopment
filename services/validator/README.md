# Validator-as-a-Service

A lightweight validator agent that accepts validation requests, runs a verification plugin, and (optionally) submits
validation responses to the on-chain `ValidationRegistry`.

## Endpoints

- `GET /health` returns available validation methods.
- `POST /validate` accepts a validation request, produces a score, and optionally submits an on-chain response.

Example request:

```json
{
  "requestHash": "0x1234",
  "agentId": 7,
  "requestUri": "ipfs://validation/request.json",
  "method": "test-suite",
  "payload": {
    "passed": 18,
    "total": 20
  },
  "responseUri": "ipfs://validation/response.json",
  "tag": "unit-tests"
}
```

Example response:

```json
{
  "requestHash": "0x1234",
  "agentId": 7,
  "method": "test-suite",
  "score": 90,
  "responseUri": "ipfs://validation/response.json",
  "responseHash": "0xabcd",
  "tag": "unit-tests",
  "details": "18 of 20 tests passed.",
  "submitted": false,
  "txHash": null
}
```

## Configuration

Set environment variables to enable on-chain submission:

- `VALIDATOR_PORT` (default: `4100`)
- `RPC_URL`
- `VALIDATOR_PRIVATE_KEY`
- `VALIDATOR_REGISTRY_ADDRESS`

## Validation plugins

- **deterministic-reexecution**: Compares expected vs. actual output or exit code.
- **test-suite**: Computes a score from passed/total test counts.
- **tee-attestation**: Placeholder for TEE attestation verification.
- **zk-proof**: Placeholder for ZK proof verification.

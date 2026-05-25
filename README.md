# Weave Protocol Stress-Test Substrate (Foundry)

Minimal Solidity substrate for delegation-policy composition and commitment-chain auditing.

## Scope

- Local-only stress-test harness (no testnet deployment)
- Foundry tests for the collusion scenario
- Invariant scaffold for denylist safety checks

## Contracts

- `src/DelegationRegistry.sol`
- `src/IntentRegistry.sol`
- `src/CommitmentRegistry.sol`
- `src/PolicyEngine.sol`
- `src/Auditor.sol`
- `src/Supervisor.sol`

## Tests

- `test/CollusionScenario.t.sol`

## Quickstart

1. Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Run scenario tests:

```bash
forge test --match-contract CollusionScenarioTest -vv
```

3. Run invariant checks:

```bash
forge test --match-contract CollusionInvariantTest -vv
```

## Notes

- This is intentionally a reference harness, not a production protocol implementation.
- Signature verification and strong access control are stubbed for rapid iteration.

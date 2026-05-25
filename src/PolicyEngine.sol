// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DelegationRegistry} from "./DelegationRegistry.sol";
import {IntentRegistry} from "./IntentRegistry.sol";

contract PolicyEngine {
    enum Decision {
        REJECT,
        ACCEPT
    }

    struct PDR {
        Decision decision;
        bytes32 reason;
    }

    bytes32 public constant REASON_OK = keccak256("OK");
    bytes32 public constant REASON_INTENT_NOT_FOUND = keccak256("INTENT_NOT_FOUND");
    bytes32 public constant REASON_DELEGATION_NOT_FOUND = keccak256("DELEGATION_NOT_FOUND");
    bytes32 public constant REASON_REVOKED_OR_EXPIRED = keccak256("REVOKED_OR_EXPIRED");
    bytes32 public constant REASON_DENYLIST_HIT = keccak256("DENYLIST_HIT");

    DelegationRegistry public immutable delegations;
    IntentRegistry public immutable intents;

    event PDRAccept(bytes32 indexed intentId, bytes32 indexed delegationId, bool composed);
    event PDRReject(bytes32 indexed intentId, bytes32 indexed delegationId, bool composed, bytes32 reason);

    constructor(address delegationRegistry, address intentRegistry) {
        delegations = DelegationRegistry(delegationRegistry);
        intents = IntentRegistry(intentRegistry);
    }

    function evaluate(bytes32 intentId, bytes32 delegationId) external view returns (PDR memory) {
        return _evaluate(intentId, delegationId, true);
    }

    function evaluate(bytes32 intentId, bytes32 delegationId, bool composeScopes) external view returns (PDR memory) {
        return _evaluate(intentId, delegationId, composeScopes);
    }

    function evaluateAndEmit(bytes32 intentId, bytes32 delegationId, bool composeScopes) external returns (PDR memory pdr) {
        pdr = _evaluate(intentId, delegationId, composeScopes);
        if (pdr.decision == Decision.ACCEPT) {
            emit PDRAccept(intentId, delegationId, composeScopes);
        } else {
            emit PDRReject(intentId, delegationId, composeScopes, pdr.reason);
        }
    }

    function _evaluate(bytes32 intentId, bytes32 delegationId, bool composeScopes) internal view returns (PDR memory) {
        IntentRegistry.Intent memory intent = intents.getIntent(intentId);
        if (!intent.exists) {
            return PDR({decision: Decision.REJECT, reason: REASON_INTENT_NOT_FOUND});
        }

        if (!delegations.exists(delegationId)) {
            return PDR({decision: Decision.REJECT, reason: REASON_DELEGATION_NOT_FOUND});
        }

        if (composeScopes) {
            bytes32 current = delegationId;
            while (current != bytes32(0)) {
                if (!delegations.isActive(current)) {
                    return PDR({decision: Decision.REJECT, reason: REASON_REVOKED_OR_EXPIRED});
                }
                if (delegations.isAddressDenylisted(current, intent.destination)) {
                    return PDR({decision: Decision.REJECT, reason: REASON_DENYLIST_HIT});
                }
                current = delegations.getParent(current);
            }
        } else {
            if (!delegations.isActive(delegationId)) {
                return PDR({decision: Decision.REJECT, reason: REASON_REVOKED_OR_EXPIRED});
            }
            if (delegations.isAddressDenylisted(delegationId, intent.destination)) {
                return PDR({decision: Decision.REJECT, reason: REASON_DENYLIST_HIT});
            }
        }

        return PDR({decision: Decision.ACCEPT, reason: REASON_OK});
    }
}

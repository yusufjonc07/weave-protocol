// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DelegationRegistry} from "../src/DelegationRegistry.sol";
import {IntentRegistry} from "../src/IntentRegistry.sol";
import {CommitmentRegistry} from "../src/CommitmentRegistry.sol";
import {PolicyEngine} from "../src/PolicyEngine.sol";
import {Auditor} from "../src/Auditor.sol";

contract CollusionScenarioTest {
    DelegationRegistry internal delegations;
    IntentRegistry internal intents;
    CommitmentRegistry internal commitments;
    PolicyEngine internal policy;
    Auditor internal auditor;

    address internal constant P = address(0x1001);
    address internal constant A = address(0x1002);
    address internal constant B = address(0x1003);
    address internal constant X = address(0x9001);

    bytes4 internal constant SWAP = bytes4(keccak256("SWAP"));
    bytes4 internal constant FORWARD = bytes4(keccak256("FORWARD"));

    function setUp() public {
        delegations = new DelegationRegistry();
        intents = new IntentRegistry();
        commitments = new CommitmentRegistry();
        policy = new PolicyEngine(address(delegations), address(intents));
        auditor = new Auditor(address(commitments));
    }

    function test_collusionDetected_whenPolicyComposes() public {
        bytes32 delPA = delegations.issue(P, A, _singleAddressArray(X), 50_000, 0, DelegationRegistry.Action.ANY);

        bytes32 delAB = delegations.subDelegate(
            B,
            delPA,
            _emptyAddressArray(),
            50_000,
            0,
            DelegationRegistry.Action.FORWARD_ONLY
        );

        bytes32 intent1 = intents.publish(A, delPA, SWAP, address(0), keccak256("swap_payload"), 0, 1, bytes32(0));
        _ignore(intent1);

        bytes32 intent2 = intents.publish(B, delAB, FORWARD, X, keccak256("forward_payload"), 0, 2, bytes32(0));

        PolicyEngine.PDR memory result = policy.evaluate(intent2, delAB);
        assertEq(uint256(result.decision), uint256(PolicyEngine.Decision.REJECT), "expected composed policy rejection");
    }

    function test_collusionReconstructible_whenPolicyOmitsComposition() public {
        bytes32 delPA = delegations.issue(P, A, _singleAddressArray(X), 50_000, 0, DelegationRegistry.Action.ANY);

        bytes32 delAB = delegations.subDelegate(
            B,
            delPA,
            _emptyAddressArray(),
            50_000,
            0,
            DelegationRegistry.Action.FORWARD_ONLY
        );

        bytes32 intent1 = intents.publish(A, delPA, SWAP, address(0), keccak256("swap_payload"), 0, 1, bytes32(0));
        bytes32 intent2 = intents.publish(B, delAB, FORWARD, X, keccak256("forward_payload"), 0, 2, bytes32(0));

        bytes32 c1 = commitments.publish(A, intent1, bytes32(0), address(0), keccak256("sig1"));
        bytes32 c2 = commitments.publish(B, intent2, c1, X, keccak256("sig2"));

        PolicyEngine.PDR memory brokenResult = policy.evaluate(intent2, delAB, false);
        assertEq(uint256(brokenResult.decision), uint256(PolicyEngine.Decision.ACCEPT), "expected local-only acceptance");

        commitments.setPolicyDecision(c2, true);

        bytes32[] memory chains = auditor.commitmentChainsTerminatingAt(X);
        assertEq(chains.length, 1, "expected one reconstructible chain");
        assertEq(chains[0], c2, "chain endpoint mismatch");
    }

    function _singleAddressArray(address a) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = a;
    }

    function _emptyAddressArray() internal pure returns (address[] memory arr) {
        arr = new address[](0);
    }

    function _ignore(bytes32) internal pure {}

    function assertEq(uint256 left, uint256 right, string memory err) internal pure {
        require(left == right, err);
    }

    function assertEq(bytes32 left, bytes32 right, string memory err) internal pure {
        require(left == right, err);
    }
}

contract CollusionInvariantTest {
    DelegationRegistry internal delegations;
    IntentRegistry internal intents;
    CommitmentRegistry internal commitments;
    PolicyEngine internal policy;
    Auditor internal auditor;

    address internal constant P = address(0x2001);
    address internal constant A = address(0x2002);
    address internal constant B = address(0x2003);
    address internal constant X = address(0x9001);

    bytes4 internal constant FORWARD = bytes4(keccak256("FORWARD"));

    function setUp() public {
        delegations = new DelegationRegistry();
        intents = new IntentRegistry();
        commitments = new CommitmentRegistry();
        policy = new PolicyEngine(address(delegations), address(intents));
        auditor = new Auditor(address(commitments));

        bytes32 delPA = delegations.issue(P, A, _singleAddressArray(X), 10_000, 0, DelegationRegistry.Action.ANY);
        bytes32 delAB = delegations.subDelegate(
            B,
            delPA,
            _emptyAddressArray(),
            10_000,
            0,
            DelegationRegistry.Action.FORWARD_ONLY
        );

        bytes32 intent = intents.publish(B, delAB, FORWARD, X, keccak256("payload"), 0, 1, bytes32(0));
        bytes32 commitmentId = commitments.publish(B, intent, bytes32(0), X, keccak256("sig"));

        PolicyEngine.PDR memory pdr = policy.evaluate(intent, delAB, true);
        commitments.setPolicyDecision(commitmentId, pdr.decision == PolicyEngine.Decision.ACCEPT);
    }

    function invariant_noChainTerminatesAtDenylistedAddress() public view {
        bytes32[] memory chains = auditor.commitmentChainsTerminatingAt(X);
        for (uint256 i = 0; i < chains.length; i++) {
            require(!auditor.wasAcceptedByPolicy(chains[i]), "accepted denylisted terminal chain");
        }
    }

    function _singleAddressArray(address a) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = a;
    }

    function _emptyAddressArray() internal pure returns (address[] memory arr) {
        arr = new address[](0);
    }
}

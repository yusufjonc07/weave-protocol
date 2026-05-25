// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CommitmentRegistry} from "./CommitmentRegistry.sol";

contract Auditor {
    CommitmentRegistry public immutable commitments;

    constructor(address commitmentRegistry) {
        commitments = CommitmentRegistry(commitmentRegistry);
    }

    function commitmentChainsTerminatingAt(address terminal) external view returns (bytes32[] memory) {
        bytes32[] memory allCommitments = commitments.getAllCommitmentIds();
        uint256 count = 0;

        for (uint256 i = 0; i < allCommitments.length; i++) {
            CommitmentRegistry.Commitment memory c = commitments.getCommitment(allCommitments[i]);
            if (c.terminalAddress == terminal) {
                count++;
            }
        }

        bytes32[] memory matches = new bytes32[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < allCommitments.length; i++) {
            CommitmentRegistry.Commitment memory c = commitments.getCommitment(allCommitments[i]);
            if (c.terminalAddress == terminal) {
                matches[idx] = c.id;
                idx++;
            }
        }

        return matches;
    }

    function wasAcceptedByPolicy(bytes32 commitmentId) external view returns (bool) {
        return commitments.wasAcceptedByPolicy(commitmentId);
    }
}

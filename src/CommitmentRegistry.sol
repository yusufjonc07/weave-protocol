// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract CommitmentRegistry {
    struct Commitment {
        bytes32 id;
        address publisher;
        bytes32 intentId;
        bytes32 previousCommitmentId;
        address terminalAddress;
        bytes32 signatureHash;
        bool acceptedByPolicy;
        bool exists;
    }

    mapping(bytes32 => Commitment) private _commitments;
    bytes32[] private _allCommitmentIds;

    event CommitmentPublished(bytes32 indexed id, address indexed publisher, bytes32 indexed intentId);
    event PolicyDecisionRecorded(bytes32 indexed id, bool acceptedByPolicy);

    function publish(
        address publisher,
        bytes32 intentId,
        bytes32 previousCommitmentId,
        address terminalAddress,
        bytes32 signatureHash
    ) external returns (bytes32 id) {
        id = keccak256(
            abi.encode(
                block.chainid,
                publisher,
                intentId,
                previousCommitmentId,
                terminalAddress,
                signatureHash,
                _allCommitmentIds.length
            )
        );

        _commitments[id] = Commitment({
            id: id,
            publisher: publisher,
            intentId: intentId,
            previousCommitmentId: previousCommitmentId,
            terminalAddress: terminalAddress,
            signatureHash: signatureHash,
            acceptedByPolicy: false,
            exists: true
        });

        _allCommitmentIds.push(id);
        emit CommitmentPublished(id, publisher, intentId);
    }

    function setPolicyDecision(bytes32 commitmentId, bool acceptedByPolicy) external {
        Commitment storage c = _commitments[commitmentId];
        require(c.exists, "COMMITMENT_NOT_FOUND");
        c.acceptedByPolicy = acceptedByPolicy;
        emit PolicyDecisionRecorded(commitmentId, acceptedByPolicy);
    }

    function getCommitment(bytes32 commitmentId) external view returns (Commitment memory) {
        return _commitments[commitmentId];
    }

    function wasAcceptedByPolicy(bytes32 commitmentId) external view returns (bool) {
        return _commitments[commitmentId].acceptedByPolicy;
    }

    function getAllCommitmentIds() external view returns (bytes32[] memory) {
        return _allCommitmentIds;
    }
}

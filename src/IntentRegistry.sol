// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract IntentRegistry {
    struct Intent {
        bytes32 id;
        address publisher;
        bytes32 delegationId;
        bytes4 intentType;
        address destination;
        bytes32 payloadHash;
        uint64 deadline;
        uint256 nonce;
        bytes32 signatureHash;
        bool exists;
    }

    mapping(bytes32 => Intent) private _intents;
    bytes32[] private _allIntentIds;

    event IntentPublished(bytes32 indexed id, address indexed publisher, bytes32 indexed delegationId);

    function publish(
        address publisher,
        bytes32 delegationId,
        bytes4 intentType,
        address destination,
        bytes32 payloadHash,
        uint64 deadline,
        uint256 nonce,
        bytes32 signatureHash
    ) external returns (bytes32 id) {
        id = keccak256(
            abi.encode(
                block.chainid,
                publisher,
                delegationId,
                intentType,
                destination,
                payloadHash,
                deadline,
                nonce,
                _allIntentIds.length
            )
        );

        _intents[id] = Intent({
            id: id,
            publisher: publisher,
            delegationId: delegationId,
            intentType: intentType,
            destination: destination,
            payloadHash: payloadHash,
            deadline: deadline,
            nonce: nonce,
            signatureHash: signatureHash,
            exists: true
        });

        _allIntentIds.push(id);
        emit IntentPublished(id, publisher, delegationId);
    }

    function getIntent(bytes32 intentId) external view returns (Intent memory) {
        return _intents[intentId];
    }

    function exists(bytes32 intentId) external view returns (bool) {
        return _intents[intentId].exists;
    }

    function getAllIntentIds() external view returns (bytes32[] memory) {
        return _allIntentIds;
    }
}

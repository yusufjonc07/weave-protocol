// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DelegationRegistry} from "./DelegationRegistry.sol";

contract Supervisor {
    DelegationRegistry public immutable delegations;
    uint256 public immutable threshold;

    mapping(address => bool) public isSigner;
    mapping(bytes32 => uint256) public approvals;
    mapping(bytes32 => mapping(address => bool)) public hasApproved;

    event RevocationProposed(bytes32 indexed delegationId, address indexed signer, uint256 approvals);
    event RevocationExecuted(bytes32 indexed delegationId);

    constructor(address delegationRegistry, address[] memory signers, uint256 m) {
        require(signers.length > 0, "NO_SIGNERS");
        require(m > 0 && m <= signers.length, "BAD_THRESHOLD");
        delegations = DelegationRegistry(delegationRegistry);
        threshold = m;

        for (uint256 i = 0; i < signers.length; i++) {
            isSigner[signers[i]] = true;
        }
    }

    function proposeRevoke(bytes32 delegationId) external {
        require(isSigner[msg.sender], "NOT_SIGNER");
        require(!hasApproved[delegationId][msg.sender], "ALREADY_APPROVED");

        hasApproved[delegationId][msg.sender] = true;
        approvals[delegationId]++;

        emit RevocationProposed(delegationId, msg.sender, approvals[delegationId]);

        if (approvals[delegationId] >= threshold) {
            delegations.forceRevoke(delegationId);
            emit RevocationExecuted(delegationId);
        }
    }
}

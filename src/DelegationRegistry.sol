// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract DelegationRegistry {
    enum Action {
        ANY,
        FORWARD_ONLY,
        SWAP_ONLY
    }

    struct Delegation {
        bytes32 id;
        bytes32 parentId;
        address principal;
        address agent;
        Action action;
        uint256 cap;
        uint64 expiry;
        bool revoked;
    }

    mapping(bytes32 => Delegation) private _delegations;
    mapping(bytes32 => address[]) private _delegationDenylist;
    mapping(bytes32 => mapping(address => bool)) private _denylisted;
    bytes32[] private _allDelegationIds;

    address public supervisor;

    event DelegationIssued(bytes32 indexed id, address indexed principal, address indexed agent);
    event DelegationRevoked(bytes32 indexed id);

    function setSupervisor(address newSupervisor) external {
        require(supervisor == address(0), "SUPERVISOR_ALREADY_SET");
        supervisor = newSupervisor;
    }

    function issue(
        address principal,
        address agent,
        address[] calldata denylist,
        uint256 cap,
        uint64 expiry,
        Action action
    ) external returns (bytes32 id) {
        id = keccak256(abi.encode(block.chainid, principal, agent, _allDelegationIds.length));
        _storeDelegation(id, bytes32(0), principal, agent, denylist, cap, expiry, action);
    }

    function subDelegate(
        address subAgent,
        bytes32 parentId,
        address[] calldata denylist,
        uint256 cap,
        uint64 expiry,
        Action action
    ) external returns (bytes32 id) {
        Delegation memory parent = _delegations[parentId];
        require(parent.id != bytes32(0), "PARENT_NOT_FOUND");

        id = keccak256(
            abi.encode(block.chainid, parent.principal, parent.agent, subAgent, parentId, _allDelegationIds.length)
        );
        _storeDelegation(id, parentId, parent.principal, subAgent, denylist, cap, expiry, action);
    }

    function revoke(bytes32 delegationId) external {
        Delegation storage delegation = _delegations[delegationId];
        require(delegation.id != bytes32(0), "DELEGATION_NOT_FOUND");
        delegation.revoked = true;
        emit DelegationRevoked(delegationId);
    }

    function forceRevoke(bytes32 delegationId) external {
        require(msg.sender == supervisor, "ONLY_SUPERVISOR");
        Delegation storage delegation = _delegations[delegationId];
        require(delegation.id != bytes32(0), "DELEGATION_NOT_FOUND");
        delegation.revoked = true;
        emit DelegationRevoked(delegationId);
    }

    function getDelegation(bytes32 delegationId) external view returns (Delegation memory) {
        return _delegations[delegationId];
    }

    function getDenylist(bytes32 delegationId) external view returns (address[] memory) {
        return _delegationDenylist[delegationId];
    }

    function isAddressDenylisted(bytes32 delegationId, address target) external view returns (bool) {
        return _denylisted[delegationId][target];
    }

    function exists(bytes32 delegationId) external view returns (bool) {
        return _delegations[delegationId].id != bytes32(0);
    }

    function isActive(bytes32 delegationId) external view returns (bool) {
        Delegation memory delegation = _delegations[delegationId];
        if (delegation.id == bytes32(0)) return false;
        if (delegation.revoked) return false;
        if (delegation.expiry != 0 && block.timestamp > delegation.expiry) return false;
        return true;
    }

    function getParent(bytes32 delegationId) external view returns (bytes32) {
        return _delegations[delegationId].parentId;
    }

    function getAllDelegationIds() external view returns (bytes32[] memory) {
        return _allDelegationIds;
    }

    function _storeDelegation(
        bytes32 id,
        bytes32 parentId,
        address principal,
        address agent,
        address[] calldata denylist,
        uint256 cap,
        uint64 expiry,
        Action action
    ) internal {
        require(_delegations[id].id == bytes32(0), "DELEGATION_EXISTS");
        Delegation storage delegation = _delegations[id];
        delegation.id = id;
        delegation.parentId = parentId;
        delegation.principal = principal;
        delegation.agent = agent;
        delegation.action = action;
        delegation.cap = cap;
        delegation.expiry = expiry;
        delegation.revoked = false;

        for (uint256 i = 0; i < denylist.length; i++) {
            address denied = denylist[i];
            _delegationDenylist[id].push(denied);
            _denylisted[id][denied] = true;
        }

        _allDelegationIds.push(id);
        emit DelegationIssued(id, principal, agent);
    }
}

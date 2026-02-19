// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

interface IRolesAdmin {
    function allowFor(address _contract, bytes32 _role, bool _allowed) external;

    function isAllowedFor(address _contract, bytes32 _role) external view returns (bool);
}

/// @title AuthLibrary
/// @author Merge Layers Inc.
/// @notice Library for managing role permissions using the Roles registry
library AuthLibrary {
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Thrown when a role update does not persist on the Roles registry
    error RoleNotSet(address roles, address target, bytes32 role, bool expectedState);

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @notice Grants or revokes a role for a target using Malda `Roles.allowFor`
    /// @dev Malda does not use capability-based role permissions (RolesAuthority model)
    /// @param roles The address of the Roles registry
    /// @param target The address of the target
    /// @param role The bytes32 role identifier
    /// @param isGranted Whether the role is granted or revoked (true = grant, false = revoke)
    function grantRole(address roles, address target, bytes32 role, bool isGranted) internal {
        IRolesAdmin rolesRegistry = IRolesAdmin(roles);

        // Interactions: grant or revoke the role
        rolesRegistry.allowFor(target, role, isGranted);

        // Requirements: the role is set correctly as expected
        require(rolesRegistry.isAllowedFor(target, role) == isGranted, RoleNotSet(roles, target, role, isGranted));
    }
}

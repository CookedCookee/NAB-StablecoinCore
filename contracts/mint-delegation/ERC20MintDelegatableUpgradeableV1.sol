// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

/**
 * Copyright (C) 2022 National Australia Bank Limited
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not,
 * see <https://www.gnu.org/licenses/>.
 */

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../lib/LibErrorsV1.sol";

/**
 * @title ERC20 Mint Delegatable Upgradeable (V1)
 * @author National Australia Bank Limited
 * @notice This abstract contract defines Mint Delegation with RBAC privilege rules. In this case,
 * {ERC20MintDelegatable} is designed to be incorporated by {StablecoinCoreV1}.
 *
 * Delegating Supply Control comprises provisioning multiple accounts with Minting and Burning privileges.
 *
 * In particular, Mint functionality is also bound to mint allowances for each Minter. This contract provides
 * functions for:
 *
 * - Adding and removing Supply Control pairs
 * - Increasing and decreasing Mint allowances
 *
 * @dev It uses the OpenZeppelin extension {AccessControlEnumerable}, which allows enumerating the members
 * of each role.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed in the external API and be unique.
 * The best way to achieve this is by using `public constant` hash digests:
 *
 * The {grantRole} and {revokeRole} functions MUST be configured here, to be able to dynamically grant
 * and revoke Roles, where applicable. For example, the "MINTER_ROLE" and "BURNER_ROLE" roles
 * are NOT to be handled dynamically.
 *
 * The admin role for "MINTER_ROLE" and "BURNER_ROLE" roles must be "SUPPLY_DELEGATION_ADMIN_ROLE" and as such it
 * will control the provision of such roles, although not via {grantRole} and {revokeRole}. Instead,
 * {_addSupplyControlPair} and {_removeSupplyControlPair} are to be used.
 *
 */
abstract contract ERC20MintDelegatableUpgradeableV1 is ERC20Upgradeable, AccessControlEnumerableUpgradeable {
    /// Constants

    /**
     * @notice The Access Control identifier for the Burner Role.
     *
     * An account with "BURNER_ROLE" can burn part or all tokens in it's balance.
     *
     * @dev This constant holds the hash of the string "BURNER_ROLE".
     */
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /**
     * @notice The Access Control identifier for the Minter Role.
     *
     * An account with "MINTER_ROLE" can mint new tokens, per the minting allowance delegated to them by
     * "MINT_ALLOWANCE_ADMIN_ROLE".
     *
     * @dev This constant holds the hash of the string "MINTER_ROLE".
     */
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @notice The Access Control identifier for the Supply Delegation Admin Role.
     *
     * An account with "SUPPLY_DELEGATION_ADMIN_ROLE" can add and remove Minter-Burner pairs.
     *
     * @dev This constant holds the hash of the string "SUPPLY_DELEGATION_ADMIN_ROLE".
     */
    bytes32 public constant SUPPLY_DELEGATION_ADMIN_ROLE = keccak256("SUPPLY_DELEGATION_ADMIN_ROLE");

    /**
     * @notice The Access Control identifier for the Mint Allowance Admin Role.
     *
     * An account with "MINT_ALLOWANCE_ADMIN_ROLE" can increase and decrease a Minter's minting allowance.
     *
     * @dev This constant holds the hash of the string "MINT_ALLOWANCE_ADMIN_ROLE".
     */
    bytes32 public constant MINT_ALLOWANCE_ADMIN_ROLE = keccak256("MINT_ALLOWANCE_ADMIN_ROLE");

    /// State

    /**
     * @notice This is a dictionary that maps a Minter `address` to the corresponding Burner `address`
     * it is paired with.
     *
     * @dev {StablecoinCoreV1} Delegated Minting state. `_supplyPairMinterToBurner` represents the Minter
     * relationship cardinality as a 1-to-1 in a Minter-Burner pair.
     *
     * Key: minter (address).
     * Value: burner (address).
     */
    mapping(address => address) private _supplyPairMinterToBurner;

    /**
     * @notice This is a dictionary that keeps track of the amount of Minters an `address` is currently
     * paired to (as a Burner) in Minter-Burner pairs.
     *
     * @dev {StablecoinCoreV1} Delegated Minting state. `_burnerPairCount` represents the Burner
     * relationship cardinality as a 1-to-many for Minter-Burner pairs.
     *
     * Key: burner (address).
     * Value: cardinality (uint256).
     */
    mapping(address => uint256) private _burnerPairCount;

    /**
     * @notice This is a dictionary that holds the minting allowance for each registered Minter.
     *
     * @dev {StablecoinCoreV1} Delegated Minting state. State variable for minting allowances.
     *
     * Key: minter (address).
     * Value: minting allowance (uint256).
     */
    mapping(address => uint256) private _mintAllowances;

    // Events

    /**
     * @notice This is an event that logs the creation of a Minter-Burner Supply Control pair.
     *
     * @dev Emitted when a pair of `minter` and `burner` is registered.
     *
     * @param sender The (indexed) account that originated the contract call. It should be a
     * "SUPPLY_DELEGATION_ADMIN_ROLE" role bearer.
     * @param minter The (indexed) account that was granted "MINTER_ROLE" privileges.
     * @param burner The (indexed) account that was granted "BURNER_ROLE" privileges (if not already present).
     */
    event SupplyDelegationPairAdded(address indexed sender, address indexed minter, address indexed burner);

    /**
     * @notice This is an event that logs the removal of a Minter-Burner Supply Control pair.
     *
     * @dev Emitted when a pair of `minter` and `burner` is removed.
     *
     * @param sender The (indexed) account that originated the contract call. It should be a
     * "SUPPLY_DELEGATION_ADMIN_ROLE" role bearer.
     * @param minter The (indexed) account that had its "MINTER_ROLE" revoked.
     * @param burner The (indexed) account that may have had its "BURNER_ROLE" revoked.
     * @param mintAllowance The mint allowance that was forgone by `minter`.
     */
    event SupplyDelegationPairRemoved(
        address indexed sender,
        address indexed minter,
        address indexed burner,
        uint256 mintAllowance
    );

    /**
     * @notice This is an event that logs whenever a minting allowance is increased.
     * @param sender The (indexed) address that increased the minting allowance of `minter`.
     * @param minter The (indexed) address that had its minting allowance increased.
     * @param postAllowance The minting allowance of the `minter` address after the increase.
     * @param amount The amount that the minting allowance was increased by.
     */
    event MintAllowanceIncreased(
        address indexed sender,
        address indexed minter,
        uint256 postAllowance,
        uint256 amount
    );

    /**
     * @notice This is an event that logs whenever a minting allowance is decreased.
     * @param sender The (indexed) address that decreased the minting allowance of `minter`.
     * @param minter The (indexed) address that had its minting allowance decreased.
     * @param postAllowance The minting allowance of the `minter` address after the decrease.
     * @param amount The amount that the minting allowance was decreased by.
     */
    event MintAllowanceDecreased(
        address indexed sender,
        address indexed minter,
        uint256 postAllowance,
        uint256 amount
    );

    /// Functions

    // @dev Initializing function for ERC20MintDelegatableUpgradeable.
    /* solhint-disable */
    function __ERC20MintDelegatable_init() internal onlyInitializing {}

    /* solhint-enable */

    /**
     * @notice This is a function used to get the minting allowance of an address.
     * @param minter The address to get the minting allowance for.
     * @return The minting allowance delegated to the `minter`.
     */
    function getMintAllowance(address minter) public view virtual returns (uint256) {
        return _getMintAllowance(minter);
    }

    /**
     * @notice This is a function used to increase the minting allowance of a minter.
     * @dev Reverts if the sender is not "MINT_ALLOWANCE_ADMIN_ROLE".
     *
     * This function might emit a {MintAllowanceIncreased} event as part of {_increaseMintingAllowance}.
     *
     * Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "MINT_ALLOWANCE_ADMIN_ROLE".
     * - `minter` is a non-zero address.
     * - `amount` is greater than 0.
     *
     * @param minter This address holds the "MINTER_ROLE" and will get its minting allowance increased.
     * @param amount The amount that the minting allowance was increased by.
     */
    function mintAllowanceIncrease(address minter, uint256 amount) public virtual onlyRole(MINT_ALLOWANCE_ADMIN_ROLE) {
        if (minter == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("minter");
        }
        if (amount == 0) {
            revert LibErrorsV1.ZeroValuedParameter("amount");
        }
        require(hasRole(MINTER_ROLE, minter), "Address is not a minter");
        _increaseMintingAllowance(minter, amount);
    }

    /**
     * @notice This is a function used to decrease minting allowance to a minter.
     * @dev Reverts if the sender is not "MINT_ALLOWANCE_ADMIN_ROLE".
     *
     * This function might emit a {MintAllowanceDecreased} event as part of {_decreaseMintingAllowance}.
     *
     * Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "MINT_ALLOWANCE_ADMIN_ROLE".
     * - `minter` is a non-zero address.
     * - `amount` is greater than 0.
     *
     * The Mint allowance for any Minter cannot assume a negative value. The request is only processed if the decrease
     * is less than the current mint allowance.
     *
     * @param minter This address will get its minting allowance decreased.
     * @param amount The amount that the minting allowance was decreased by.
     */
    function mintAllowanceDecrease(address minter, uint256 amount) public virtual onlyRole(MINT_ALLOWANCE_ADMIN_ROLE) {
        if (minter == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("minter");
        }
        if (amount == 0) {
            revert LibErrorsV1.ZeroValuedParameter("amount");
        }
        _decreaseMintingAllowance(minter, amount);
    }

    /**
     * @notice This function creates a Minter-Burner pair and adds it to the appropriate registries.
     *
     * @dev Grants "MINTER_ROLE" to `minter` and emits a {RoleGranted} event. Likewise, grants "BURNER_ROLE" to `burner`
     * and if `burner` had not already been granted "BURNER_ROLE", emits a {RoleGranted} event.
     *
     * Internal function without access restriction. Minter addresses may only be part of one Minter-Burner pair.
     * Burners however can belong to multiple Minter-Burner pairs. This affords us the option of having a unified
     * Burner address for a cohort of ERC20s.
     *
     * Minter and Burner can be the same address.
     *
     * Calling Conditions:
     *
     * - `minter` is not part of an already-registered Supply pair.
     * - Non-zero address `minter`.
     * - Non-zero address `burner`.
     * - `minter must not be a part of any other Minter-Burner pair.
     *
     * This function emits at least 1x {RoleGranted} event.
     *
     * @param minter The address which will assume the "MINTER_ROLE" of the Minter-Burner pair.
     * @param burner The address which will assume the "BURNER_ROLE" of the Minter-Burner pair.
     */
    function _addSupplyControlPair(address minter, address burner) internal {
        if (minter == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("minter");
        }
        if (burner == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("burner");
        }
        require(_supplyPairMinterToBurner[minter] == address(0), "A Supply pair exists for minter");

        // Register Minter-Burner Supply pair
        _supplyPairMinterToBurner[minter] = burner;
        _burnerPairCount[burner] = _burnerPairCount[burner] + 1;

        // Grant roles
        _grantRole(MINTER_ROLE, minter);
        _grantRole(BURNER_ROLE, burner);
    }

    /**
     * @notice This function removes a Minter-Burner pair from the appropriate registries.
     *
     * @dev Revokes "MINTER_ROLE" from `minter` and emits a {RoleRevoked} event. Likewise, if after removing
     * the Supply pair `burner` is no longer a member of any pair, revokes "BURNER_ROLE" from `burner`
     * emitting a {RoleRevoked} event.
     *
     * Internal function without access restriction.
     *
     * Calling Conditions:
     *
     * - Non-zero address `minter`.
     * - Non-zero address `burner`.
     * - `minter` and `burner` are a registered pair.
     *
     * This function emits at least 1x {RoleRevoked} event.
     *
     * @param minter The address of the Minter in a Minter-Burner pair.
     * @param burner The address of the Burner in a Minter-Burner pair.
     */
    function _removeSupplyControlPair(address minter, address burner) internal {
        if (minter == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("minter");
        }
        if (burner == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("burner");
        }
        require(_supplyPairMinterToBurner[minter] != address(0), "Minter not in a Supply pair");
        require(_burnerPairCount[burner] > 0, "Burner not in a Supply pair");
        require(_supplyPairMinterToBurner[minter] == burner, "No such Minter-Burner pair");

        // Zero-out minter's minting allowance
        _decreaseMintingAllowance(minter, _getMintAllowance(minter));

        // Remove Minter-Burner Supply pair. Decrease number of pairs this Burner is part of.
        delete _supplyPairMinterToBurner[minter];
        _burnerPairCount[burner] = _burnerPairCount[burner] - 1;

        // Revoke roles
        _revokeRole(MINTER_ROLE, minter);
        if (_burnerPairCount[burner] == 0) {
            _revokeRole(BURNER_ROLE, burner);
        }
    }

    /**
     * @notice This is a function used to get the minting allowance of an address.
     * @param minter The address to get the minting allowance for.
     * @return The minting allowance delegated to the `minter`.
     */
    function _getMintAllowance(address minter) internal view virtual returns (uint256) {
        return _mintAllowances[minter];
    }

    /**
     * @notice This is a function used to increase the minting allowance of `account` address.
     *
     * @dev Internal function without access restriction.
     *
     * This function emits a {MintAllowanceIncreased} event.
     *
     * @param account The address which is having its minting allowance increased.
     * @param amount The number that minting allowance will be increased by.
     */
    function _increaseMintingAllowance(address account, uint256 amount) internal {
        _mintAllowances[account] = _mintAllowances[account] + amount;
        emit MintAllowanceIncreased(_msgSender(), account, _getMintAllowance(account), amount);
    }

    /**
     * @notice This is a function used to decrease the minting allowance of `account` address.
     *
     * @dev Internal function without access restriction.
     *
     * This function emits a {MintAllowanceDecreased} event.
     *
     * @param account The address which is having its minting allowance decreased.
     * @param amount The amount that minting allowance will be decreased by.
     */
    function _decreaseMintingAllowance(address account, uint256 amount) internal {
        require(_mintAllowances[account] >= amount, "Exceeds mint allowance");
        _mintAllowances[account] = _mintAllowances[account] - amount;
        emit MintAllowanceDecreased(_msgSender(), account, _getMintAllowance(account), amount);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    //slither-disable-next-line naming-convention
    uint256[47] private __gap;
}
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
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../interface/IERC20DeniableUpgradeableV1.sol";
import "../lib/LibErrorsV1.sol";

/**
 * @title ERC20 Deniable Upgradeable (V1)
 * @author National Australia Bank Limited
 * @notice ERC20 Deniable Upgradeable contains the common DenyList controls for the NAB cohort of participant
 * smart contracts. It follows the Openzeppelin pattern for Upgradeable contracts.
 *
 * @dev ERC20 Deniable Upgradeable implements the interface {IERC20DeniableUpgradeableV1}.
 *
 * The ERC20 Deniable Upgradeable contract Role Based Access Control employs following roles:
 *
 * - DENYLIST_ADMIN_ROLE
 * - DENYLIST_FUNDS_RETIRE_ROLE
 */
abstract contract ERC20DeniableUpgradeableV1 is
    Initializable,
    ERC20Upgradeable,
    AccessControlEnumerableUpgradeable,
    IERC20DeniableUpgradeableV1
{
    /// Constants

    /**
     * @notice The Access Control identifier for the DenyList Admin Role.
     *
     * An account with "DENYLIST_ADMIN_ROLE" can add and remove addresses in the DenyList.
     *
     * @dev This constant holds the hash of the string "DENYLIST_ADMIN_ROLE".
     */
    bytes32 public constant DENYLIST_ADMIN_ROLE = keccak256("DENYLIST_ADMIN_ROLE");

    /**
     * @notice The Access Control identifier for the DenyList Funds Retire Role.
     *
     * An account with "DENYLIST_FUNDS_RETIRE_ROLE" can remove funds from an account in the DenyList.
     *
     * @dev This constant holds the hash of the string "DENYLIST_FUNDS_RETIRE_ROLE".
     */
    bytes32 public constant DENYLIST_FUNDS_RETIRE_ROLE = keccak256("DENYLIST_FUNDS_RETIRE_ROLE");

    ///State

    /**
     * @notice This is a dictionary that tracks if an address is confirmed in DenyList or not.
     * @dev By default each address will have a corresponding value of `false` indicating that they are not added to
     * the DenyList. Once confirmed into the DenyList, the corresponding value will change to `true` indicating that
     * their access to certain functions is denied by the "DENYLIST_ADMIN_ROLE".
     *
     * Key: account (address).
     * Value: state (bool).
     *
     */
    mapping(address => bool) private _denyList;

    ///Modifiers

    /**
     * @notice This is a modifier used to confirm that the account is not in DenyList.
     * @dev Reverts when the account is in the DenyList.
     * @param account The account to be checked if it is in DenyList.
     */
    modifier notInDenyList(address account) virtual {
        require(!_denyList[account], "Account in DenyList");
        _;
    }

    /// Functions

    /**
     * @notice This is a function used to admit the given list of addresses to the DenyList.
     *
     * @dev Calling Conditions:
     *
     * - The sender should have the "DENYLIST_ADMIN_ROLE" to call this function.
     * - `accounts` is not an empty array.
     * - `accounts` must have at least one non-zero address. Zero addresses won't be added to the DenyList.
     * - `accounts` list size is less than or equal to 100.
     *
     * This function adds the addresses to the `_denyList` mapping. It then
     * emits a {DenyListAddressAdded} event for each address which was successfully added to the DenyList.
     *
     * @param accounts An array of addresses to be added to the DenyList.
     */
    function denyListAdd(address[] calldata accounts) public virtual onlyRole(DENYLIST_ADMIN_ROLE) {
        if (accounts.length == 0) {
            revert LibErrorsV1.ZeroValuedParameter("accounts");
        }
        require(accounts.length <= 100, "List too long");
        bool hasNonZeroAddress = false;
        for (uint256 i = 0; i < accounts.length; ) {
            if (accounts[i] != address(0)) {
                hasNonZeroAddress = true;
                if (!_denyList[accounts[i]]) {
                    _denyList[accounts[i]] = true;
                    emit DenyListAddressAdded(_msgSender(), accounts[i], balanceOf(accounts[i]));
                }
            }
            unchecked {
                i++;
            }
        }
        if (!hasNonZeroAddress) {
            revert LibErrorsV1.ZeroValuedParameter("accounts");
        }
    }

    /**
     * @notice This is a function used to remove a list of addresses from the DenyList.
     *
     * @dev Calling Conditions:
     *
     * - The sender should have the "DENYLIST_ADMIN_ROLE" to call this function.
     * - `accounts` is not an empty array.
     * - `accounts` must have at least one non-zero address.
     * - `accounts` list size is less than or equal to 100.
     *
     *
     * This function removes the addresses from the `_denyList` mapping. It then
     * emits a {DenyListAddressRemoved} event for each address which was successfully removed from the DenyList.
     *
     * @param accounts An array of addresses to be removed from the DenyList.
     */
    function denyListRemove(address[] calldata accounts) public virtual onlyRole(DENYLIST_ADMIN_ROLE) {
        if (accounts.length == 0) {
            revert LibErrorsV1.ZeroValuedParameter("accounts");
        }
        require(accounts.length <= 100, "List too long");
        bool hasNonZeroAddress = false;
        for (uint256 i = 0; i < accounts.length; ) {
            if (accounts[i] != address(0)) {
                hasNonZeroAddress = true;
                if (_denyList[accounts[i]]) {
                    _denyList[accounts[i]] = false;
                    emit DenyListAddressRemoved(_msgSender(), accounts[i], balanceOf(accounts[i]));
                }
            }
            unchecked {
                i++;
            }
        }
        if (!hasNonZeroAddress) {
            revert LibErrorsV1.ZeroValuedParameter("accounts");
        }
    }

    /**
     * @notice A function used to remove funds from a given address.
     *
     * @dev Calling Conditions:
     *
     * - `amount` is greater than 0.
     * Emits {DenyListFundsRetired} event, signalling that the funds of given address were removed.
     *
     * @param account An address from which the funds are to be removed.
     * @param amount The amount to be removed from the account.
     */
    function fundsRetire(address account, uint256 amount) public virtual {
        if (amount == 0) {
            revert LibErrorsV1.ZeroValuedParameter("amount");
        }
        uint256 balance = balanceOf(account);
        _burn(account, amount);
        emit DenyListFundsRetired(_msgSender(), account, balance, balanceOf(account), amount);
    }

    /**
     * @notice This is a function used to check if the account is in DenyList.
     * @dev Reverts when the account is in the DenyList.
     * @param account The account to be checked if it is in DenyList.
     * @return true if the account is in DenyList. (false otherwise).
     */
    function isInDenyList(address account) public view returns (bool) {
        return _denyList[account];
    }

    /**
     * @notice Assigns Admin roles for the DenyList.
     * @dev Initialises the ERC20Deniable with the "DENYLIST_ADMIN_ROLE" and "DENYLIST_FUNDS_RETIRE_ROLE"
     * which can deny certain addresses to access this contract or remove funds from an address' balance respectively.
     *
     * Calling Conditions:
     *
     * - Can only be invoked by functions with the {initializer} or {reinitializer} modifiers.
     *
     * @param denyListAdminRoleAddress Account to be granted the "DENYLIST_ADMIN_ROLE"
     * @param denyListFundsRetireRoleAddress Account to be granted the "DENYLIST_FUNDS_RETIRE_ROLE"
     */
    /* solhint-disable func-name-mixedcase */
    function __ERC20Deniable_init(address denyListAdminRoleAddress, address denyListFundsRetireRoleAddress)
        internal
        onlyInitializing
    {
        _grantRole(DENYLIST_ADMIN_ROLE, denyListAdminRoleAddress);
        _grantRole(DENYLIST_FUNDS_RETIRE_ROLE, denyListFundsRetireRoleAddress);
    }

    /* solhint-enable func-name-mixedcase */

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    //slither-disable-next-line naming-convention
    uint256[49] private __gap;
}
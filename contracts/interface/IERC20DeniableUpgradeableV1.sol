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

/**
 * @title ERC20 DenyList Interface (V1)
 * @author National Australia Bank Limited
 * @notice ERC20 DenyList Interface is the backbone for ERC20 DenyList functionality. It outlines the functions that
 * must be implemented by child contracts and establishes how external systems should interact with it. In particular,
 * this interface outlines the common DenyList controls for the NAB cohort of participant smart contracts.
 *
 * @dev Interface for the ERC20 DenyList features.
 *
 * The ERC20 DenyList Interface contract Role Based Access Control employs following roles:
 *
 *  - DENYLIST_ADMIN_ROLE
 *  - DENYLIST_FUNDS_RETIRE_ROLE
 */
interface IERC20DeniableUpgradeableV1 {
    /// Events

    /**
     * @notice This is an event that logs when an address is added to the DenyList.
     * @dev Notifies that the logged address will be denied using functions like {transfer}, {transferFrom} and
     * {approve}.
     *
     * @param sender The (indexed) account which called the {denyListAdd} function to impose the deny restrictions
     * on the address(es).
     * @param account The (indexed) address which was confirmed as present on the DenyList.
     * @param balance The balance of the address at the moment it was added to the DenyList.
     */
    event DenyListAddressAdded(address indexed sender, address indexed account, uint256 balance);

    /**
     * @notice This is an event that logs when an address is removed from the DenyList.
     * @dev Notifies that the logged address can resume using functions like {transfer}, {transferFrom} and {approve}.
     *
     * @param sender The (indexed) account which called the {denyListRemove} function to lift the deny restrictions
     * on the address(es).
     * @param account The (indexed) address which was removed from the DenyList.
     * @param balance The balance of the address after it was removed from the DenyList.
     */
    event DenyListAddressRemoved(address indexed sender, address indexed account, uint256 balance);

    /**
     * @notice This is an event that logs when an account with either "DENYLIST_FUNDS_RETIRE_ROLE"
     * or "GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE" calls the {denyListFundsRetire} function to remove funds from address'
     * balance.
     *
     * @dev Indicates that the funds were retired and the `amount` was burnt from the `holder`'s balance.
     *
     * @param sender The (indexed) account that effected the removal of the funds from the
     * `holder`'s balance.
     * @param holder The (indexed) address whose funds were removed.
     * @param preBalance The holder's ERC-20 balance before the funds were removed.
     * @param postBalance The holder's ERC-20 balance after the funds were removed.
     * @param amount The amount which was removed from the holder's balance.
     */
    event DenyListFundsRetired(
        address indexed sender,
        address indexed holder,
        uint256 preBalance,
        uint256 postBalance,
        uint256 amount
    );

    /// Functions

    /**
     * @notice This is a function that adds a list of addresses to the DenyList. The function can be
     * called by the address which has the "DENYLIST_ADMIN_ROLE".
     *
     * @param accounts The list of addresses to be added to the DenyList.
     */
    function denyListAdd(address[] calldata accounts) external;

    /**
     * @notice This is a function that removes a list of addresses from the DenyList.
     * The function can be called by the address which has the "DENYLIST_ADMIN_ROLE".
     *
     * @param accounts The list of addresses to be removed from DenyList.
     */
    function denyListRemove(address[] calldata accounts) external;

    /**
     * @notice This is a function used to remove an asset from an address' balance. The function can be called
     * by the address which has the "DENYLIST_FUNDS_RETIRE_ROLE".
     *
     * @param account The address whose assets will be removed.
     * @param amount The amount to be removed.
     */
    function fundsRetire(address account, uint256 amount) external;

    /**
     * @notice This is a function used to check if the account is in DenyList.
     * @param account The account to be checked if it is in DenyList.
     * @return true if the account is in DenyList (false otherwise).
     */
    function isInDenyList(address account) external view returns (bool);
}
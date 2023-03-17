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
 * @title Funds Rescuable Interface (V1)
 * @author National Australia Bank Limited
 * @notice This interface describes the set of functions required to rescue foreign funds, both ERC20
 * and ETH, from a contract.
 */
interface IFundsRescuableUpgradeableV1 {
    /// Functions

    /**
     * @notice A function used to rescue ERC20 tokens sent to a contract.
     * @param beneficiary The recipient of the rescued ERC20 funds.
     * @param asset The contract address of foreign asset which is to be rescued.
     * @param amount The amount to be rescued.
     */
    function fundsRescueERC20(
        address beneficiary,
        address asset,
        uint256 amount
    ) external;

    /**
     * @notice A function used to rescue ETH sent to a contract.
     * @param beneficiary The recipient of the rescued ETH funds.
     * @param amount The amount to be rescued.
     */
    function fundsRescueETH(address beneficiary, uint256 amount) external;
}
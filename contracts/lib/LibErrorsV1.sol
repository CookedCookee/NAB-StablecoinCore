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
 * @title Custom Errors Library (V1)
 * @author National Australia Bank Limited
 * @notice This library holds the definition of custom errors as they may appear throughout the system.
 * @dev This library should be imported by consumer contracts which require the use of custom errors.
 */
library LibErrorsV1 {
    /// Errors

    /**
     * @notice Thrown when an inherited OpenZeppelin function has been disabled.
     */
    error OpenZeppelinFunctionDisabled();

    /**
     * @notice Custom error to interpret error conditions where an "empty" parameter is provided.
     * @dev Thrown by functions with a precondition on the parameter to not have a null value (0x0), but
     * a parameter with such value is provided.
     *
     * @param paramName The name of the parameter that cannot have a null value (0x0).
     */
    error ZeroValuedParameter(string paramName);
}
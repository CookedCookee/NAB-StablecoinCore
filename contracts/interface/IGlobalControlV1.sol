// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "./IFundsRescuableUpgradeableV1.sol";

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
 * @title Global Control Interface (V1)
 * @author National Australia Bank Limited
 * @notice The Global Control Interface details the interface surface the Global Control
 * makes available to participating smart contracts (e.g. Stablecoins) for shared control.
 *
 * For example the shared DenyList management and single call {pause} and {unpause}
 * patterns.
 */
interface IGlobalControlV1 is IFundsRescuableUpgradeableV1 {
    /// Functions

    /**
     * @notice This is a function used to activate Global Pause.
     *
     * This function does not pause the Global Control contract.
     */
    function activateGlobalPause() external;

    /**
     * @notice This is a function used to deactivate Global Pause.
     *
     * This function does not unpause the Global Control contract.
     */
    function deactivateGlobalPause() external;

    /**
     * @notice This function is used to remove the funds from a given user.
     * @param participantSmartContract The asset that will be removed from the `account`.
     * @param account The address for which the funds are to be removed.
     * @param amount The amount of the `asset` removed from the `account` address.
     */
    function fundsRetireERC20(
        address participantSmartContract,
        address account,
        uint256 amount
    ) external;

    /**
     * @notice This function is used to rescue ERC20 tokens from a participant contract.
     * @param participantSmartContract The contract address from which the asset is extracted.
     * @param beneficiary The recipient of the rescued ERC20 funds.
     * @param asset The contract address of the foreign asset which is to be rescued.
     * @param amount The amount to be rescued.
     */
    function participantFundsRescueERC20(
        address participantSmartContract,
        address beneficiary,
        address asset,
        uint256 amount
    ) external;

    /**
     * @notice This function is used to rescue ETH from a participant contract.
     * @param participantSmartContract The contract address from which the funds are extracted.
     * @param beneficiary The recipient of the rescued ETH funds.
     * @param amount The amount to be rescued.
     */
    function participantFundsRescueETH(
        address participantSmartContract,
        address beneficiary,
        uint256 amount
    ) external;

    /**
     * @notice This is a function used to add a list of addresses to the Global DenyList.
     * @param accounts The list of accounts that will be added to the Global DenyList.
     */
    function globalDenyListAdd(address[] memory accounts) external;

    /**
     * @notice This is a function used to remove a list of addresses from the Global DenyList.
     * @param accounts A list of accounts that will be removed from the Global DenyList.
     */
    function globalDenyListRemove(address[] memory accounts) external;

    /**
     * @notice This function is used to confirm whether an account is present on the Global Control DenyList.
     * @param inspect The account address to be assessed.
     * @return The function returns a value of "True" if an address is present in the Global DenyList.
     */
    function isGlobalDenyListed(address inspect) external view returns (bool);

    /**
     * @notice This is a function used to confirm that the contract is participating in the Stablecoin System,
     * governed by the Global Control contract.
     *
     * @param smartContract The address of the contract to be assessed.
     * @return This function returns a value of "True" if the `smartContract` address is registered
     * in the Global Control contract.
     */
    function isGlobalParticipant(address smartContract) external view returns (bool);

    /**
     * @notice This is a function used to confirm whether the Global Pause is active.
     * @return The function returns a value of "True" if the Global Pause is active.
     */
    function isGlobalPaused() external view returns (bool);

    /**
     * @notice This is a function used to pause the Global Control contract.
     * It also activates Global Pause when it is called.
     */
    function pause() external;

    /**
     * @notice This is a function used to unpause the Global Control contract.
     *
     * Restoring full operation post {pause} will, by design,
     * require calling {unpause} followed by {globalUnpause}.
     */
    function unpause() external;

    /**
     * @notice This is a function used to add a list of addresses to the Global Participant List.
     * @param participants The list of accounts that will be added to the Global Participant List.
     */
    function globalParticipantListAdd(address[] calldata participants) external;

    /**
     * @notice This is a function used to remove a list of addresses from the Global Participant List.
     * @param participants The list of accounts that will be removed from the Global Participant List.
     */
    function globalParticipantListRemove(address[] calldata participants) external;
}
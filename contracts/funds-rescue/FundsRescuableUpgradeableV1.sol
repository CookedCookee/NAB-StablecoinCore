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
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../interface/IFundsRescuableUpgradeableV1.sol";
import "../lib/LibErrorsV1.sol";

/**
 * @title Funds Rescuable Abstract (V1)
 * @author National Australia Bank Limited
 * @notice This abstract contract defines funds rescue functionality, both for ETH and ERC20 tokens.
 */
abstract contract FundsRescuableUpgradeableV1 is
    ContextUpgradeable,
    ReentrancyGuardUpgradeable,
    IFundsRescuableUpgradeableV1
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Events

    /**
     * @notice This is an event that logs whenever ERC20 funds are rescued from a contract.
     * @param sender The (indexed) address that rescued the ERC20 funds.
     * @param beneficiary The (indexed) address that received the rescued ERC20 funds.
     * @param asset The (indexed) address of the rescued asset.
     * @param amount The amount of tokens that were rescued.
     */
    event FundsRescuedERC20(address indexed sender, address indexed beneficiary, address indexed asset, uint256 amount);

    /**
     * @notice This is an event that logs whenever ETH is rescued from a contract.
     * @param sender The (indexed) address that rescued the funds.
     * @param beneficiary The (indexed) address that received the rescued ETH funds.
     * @param amount The amount of ETH that was rescued.
     */
    event FundsRescuedETH(address indexed sender, address indexed beneficiary, uint256 amount);

    /// Functions

    /**
     * @notice A function used to rescue ERC20 tokens sent to a contract.
     * @dev Calling Conditions:
     *
     * - `beneficiary` is non-zero address.
     * - `asset` is a contract.
     * - `amount` is greater than 0.
     * - `amount` is less than or equal to the contract's `asset` balance.
     * 
     * This function emits a {FundsRescuedERC20} event, indicating that funds were rescued.
     * 
     * This function could potentially call into an external contract. To protect this contract against
     * unpredictable externalities, this method:
     *
     * - Uses the safeTransfer method from {IERC20Upgradeable}.
     * - Protects against re-entrancy using the {ReentrancyGuardUpgradeable} contract.
     * 
     * @param beneficiary The recipient of the rescued ERC20 funds.
     * @param asset The contract address of foreign asset which is to be rescued.
     * @param amount The amount to be rescued.
     */
    function fundsRescueERC20(address beneficiary, address asset, uint256 amount) public virtual nonReentrant {
        if (amount == 0) {
            revert LibErrorsV1.ZeroValuedParameter("amount");
        }
        if (beneficiary == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("beneficiary");
        }
        require(AddressUpgradeable.isContract(asset), "Asset to rescue is not a contract");

        IERC20Upgradeable _token = IERC20Upgradeable(asset);
        require(_token.balanceOf(address(this)) >= amount, "Cannot rescue more than available balance");

        emit FundsRescuedERC20(_msgSender(), beneficiary, asset, amount);
        _token.safeTransfer(beneficiary, amount);
    }

    /**
     * @notice A function used to rescue ETH sent to a contract.
     * @dev Calling Conditions:
     *
     * - `beneficiary` is non-zero address.
     * - `amount` is greater than 0.
     * - `amount` is less than or equal to the contract's ETH balance.
     * 
     * This function emits a {FundsRescuedETH} event, indicating that funds were rescued.
     * 
     * This function could potentially call into an external contract. To protect this contract against
     * unpredictable externalities, this method:
     *
     * - Uses the sendValue method from {AddressUpgradeable}.
     * - Protects against reentrancy using the {ReentrancyGuardUpgradeable} contract.
     * 
     * @param beneficiary The recipient of the rescued ETH funds.
     * @param amount The amount to be rescued.
     */
    function fundsRescueETH(address beneficiary, uint256 amount) public virtual nonReentrant {
        if (amount == 0) {
            revert LibErrorsV1.ZeroValuedParameter("amount");
        }
        if (beneficiary == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("beneficiary");
        }
        require(address(this).balance >= amount, "Cannot rescue more than available balance");

        emit FundsRescuedETH(_msgSender(), beneficiary, amount);
        AddressUpgradeable.sendValue(payable(beneficiary), amount);
    }

    /* solhint-disable func-name-mixedcase */
    // @dev Initializer function for FundsRescuableUpgradeable.
    function __FundsRescuableUpgradeableV1_init() internal onlyInitializing {
        __ReentrancyGuard_init();
    }

    /* solhint-enable func-name-mixedcase */

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    //slither-disable-next-line naming-convention
    uint256[50] private __gap;
}
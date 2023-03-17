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
 * @title Stablecoin Core Interface (V1)
 * @author National Australia Bank Limited
 * @notice The Stablecoin Core (V1) Interface details the interface surface the Stablecoin Core
 * makes available to the NAB ecosystem of smart contracts.
 *
 * @dev Interface for the StableCoin Core (V1).
 */

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol";
import "./IERC20DeniableUpgradeableV1.sol";
import "./IFundsRescuableUpgradeableV1.sol";

interface IStablecoinCoreV1 is
    IERC20Upgradeable,
    IERC20MetadataUpgradeable,
    IAccessControlUpgradeable,
    IAccessControlEnumerableUpgradeable,
    IERC20DeniableUpgradeableV1,
    IERC20PermitUpgradeable,
    IFundsRescuableUpgradeableV1
{
    /**
     * @notice This is a function used to redeem tokens.
     * @param amount The number of tokens that will be destroyed.
     */
    function burn(uint256 amount) external;

    /**
     * @notice This is a function used to get the issuer.
     * @return The name of the issuer.
     */
    function getIssuer() external returns (string memory);

    /**
     * @notice This is a function used to get the rank.
     * @return The value of the rank.
     * */
    function getRank() external returns (string memory);

    /**
     * @notice This is a function used to get the link to the Content ID (CID).
     * @return The link to the id of the document containing terms and conditions.
     * */
    function getTermsCid() external view returns (string memory);

    /**
     * @notice This is a function used to issue new tokens.
     * @param account The address that will receive the issued tokens.
     * @param amount The number of tokens to be issued.
     */
    function mint(address account, uint256 amount) external;

    /**
     * @notice This is a function used to decrease minting allowance to a minter.
     * @param minter This address will get its minting allowance decreased.
     * @param amount The amount that the minting allowance was decreased by.
     */
    function mintAllowanceDecrease(address minter, uint256 amount) external;

    /**
     * @notice This is a function used to get the minting allowance of an address.
     * @param minter The address to get the minting allowance for.
     * @return The minting allowance delegated to the `minter`.
     */
    function getMintAllowance(address minter) external view returns (uint256);

    /**
     * @notice This is a function used to increase the minting allowance of a minter.
     * @param minter This address holds the "MINTER_ROLE" and will get its minting allowance increased.
     * @param amount The amount that the minting allowance was increased by.
     */
    function mintAllowanceIncrease(address minter, uint256 amount) external;

    /**
     * @notice This is a function used to increase the allowance of a spender.
     * A spender can spend an approver's balance as per their allowance.
     * This function can be used instead of {approve}.
     * @return True if the function was successful.
     */
    function increaseAllowance(address spender, uint256 increment) external returns (bool);

    /**
     * @notice This is a function used to decrease the allowance of a spender.
     * @return True if the decrease in allowance was successful, reverts otherwise.
     */
    function decreaseAllowance(address spender, uint256 decrement) external returns (bool);

    /**
     * @notice This is a function used to pause the contract.
     */
    function pause() external;

    /**
     * @notice This is a function used to check if the contract is paused on not.
     * @return true if the contract is paused, and false otherwise.
     */
    function paused() external view returns (bool);
    
    /**
     * @notice This is a function used to set the issuer.
     * @param newIssuer The value of the new issuer.
     */
    function setIssuer(string calldata newIssuer) external;

    /**
     * @notice This is a function used to set the rank.
     * @param newRank The value of the new rank.
     */
    function setRank(string calldata newRank) external;

    /**
     * @notice A function used to set the link to the Content ID (CID) which contains terms of service
     * for Stablecoin Core (V1). This document is stored on the InterPlanetary File System (IPFS).
     * @param newTermsCid The value of the new terms of service CID.
     */
    function setTermsCid(string calldata newTermsCid) external;

    /**
     * @notice This is a function used to add a Minter-Burner pair.
     * @param minter The address of the pair to be granted the "MINTER_ROLE".
     * @param burner The address of the pair to be the "BURNER_ROLE".
     */
    function supplyDelegationPairAdd(address minter, address burner) external;

    /**
     * @notice This is a function used to remove a Minter-Burner pair.
     * @param minter The address of the pair that will get its "MINTER_ROLE" revoked.
     * @param burner The address of the pair that will get its "BURNER_ROLE" revoked.
     */
    function supplyDelegationPairRemove(address minter, address burner) external;

    /**
     * @notice This is a function used to unpause the contract.
     */
    function unpause() external;
}
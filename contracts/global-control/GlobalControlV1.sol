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
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../interface/IGlobalControlV1.sol";
import "../interface/IERC20DeniableUpgradeableV1.sol";
import "../lib/LibErrorsV1.sol";
import "../funds-rescue/FundsRescuableUpgradeableV1.sol";

/**
 * @title Global Control (V1)
 * @author National Australia Bank Limited
 * @notice The Global Control contract acts as a centralised point of control for participating
 * contracts (e.g. stablecoins). The Global Control contract is concerned with DenyList management, pause
 * control and maintaining a contract registry.
 *
 * The Global Control contract Role Based Access Control employs following roles:
 *
 * - UPGRADER_ROLE
 * - PAUSER_ROLE
 * - ACCESS_CONTROL_ADMIN_ROLE
 * - PARTICIPANT_ADMIN_ROLE
 * - GLOBAL_PAUSE_ADMIN_ROLE
 * - GLOBAL_DENYLIST_ADMIN_ROLE
 * - GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE
 * - GLOBAL_FUNDS_RESCUE_ROLE
 *
 * The relationship between the Global Control's own pause state and the Global Pause being active is such that
 * when the Global Control contract is paused, Global Pause is automatically activated (but not vice versa).
 * It is valid for the Global Pause to be active and the Global Control contract to not be paused. This is useful
 * in a range of situations, for example, if we wish to add additional addresses to the DenyList.
 *
 * @dev The Global Control contract will not push, write, or update the state in participating smart contracts.
 *
 * Participation state entails the management of participating contract addresses as well as making
 * functions available to participating contracts.
 *
 * DenyList management entails the management of addresses in the DenyList as well as making functions
 * available to participating contracts.
 *
 * Pause control entails both the activation and deactivation of either the Global Pause feature or
 * this contract's pause state control, as well as making functions available to participating contracts.
 *
 * In {GlobalControlV1}, a function caller will be only checked against Global DenyList before the function proceeds
 * and not against any local DenyList.
 */
contract GlobalControlV1 is
    Initializable,
    IGlobalControlV1,
    PausableUpgradeable,
    AccessControlEnumerableUpgradeable,
    FundsRescuableUpgradeableV1,
    UUPSUpgradeable
{
    /// Constants

    /**
     * @notice The Access Control identifier for the Upgrader Role.
     *
     * An account with "UPGRADER_ROLE" can upgrade the implementation contract address.
     *
     * @dev This constant holds the hash of the string "UPGRADER_ROLE".
     */
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /**
     * @notice  The Access Control identifier for the Pauser Role.
     *
     * An account with "PAUSER_ROLE" can pause and unpause the Global Control contract. When the
     * Global Control contract has been paused, Global Pause is also activated.
     *
     * @dev This constant holds the hash of the string "PAUSER_ROLE".
     */
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @notice The Access Control identifier for the Access Control Admin Role.
     *
     * An account with "ACCESS_CONTROL_ADMIN_ROLE" can assign and revoke all the roles except itself and
     * the "UPGRADER_ROLE".
     *
     * @dev This constant holds the hash of the string "ACCESS_CONTROL_ADMIN_ROLE".
     */
    bytes32 public constant ACCESS_CONTROL_ADMIN_ROLE = keccak256("ACCESS_CONTROL_ADMIN_ROLE");

    /**
     * @notice The Access Control identifier for the Participant Admin Role.
     *
     * An account with "PARTICIPANT_ADMIN_ROLE" can add and remove addresses from the Participant List.
     *
     * @dev This constant holds the hash of the string "PARTICIPANT_ADMIN_ROLE".
     */
    bytes32 public constant PARTICIPANT_ADMIN_ROLE = keccak256("PARTICIPANT_ADMIN_ROLE");

    /**
     * @notice The Access Control identifier for the Global Pause Admin Role.
     *
     * An account with "GLOBAL_PAUSE_ADMIN_ROLE" can activate and deactivate Global Pause.
     *
     * @dev This constant holds the hash of the string "GLOBAL_PAUSE_ADMIN_ROLE".
     */
    bytes32 public constant GLOBAL_PAUSE_ADMIN_ROLE = keccak256("GLOBAL_PAUSE_ADMIN_ROLE");

    /**
     * @notice The Access Control identifier for the Global DenyList Admin Role.
     *
     * An account with "GLOBAL_DENYLIST_ADMIN_ROLE" can add and remove addresses from the Global DenyList.
     *
     * @dev This constant holds the hash of the string "GLOBAL_DENYLIST_ADMIN_ROLE".
     */
    bytes32 public constant GLOBAL_DENYLIST_ADMIN_ROLE = keccak256("GLOBAL_DENYLIST_ADMIN_ROLE");

    /**
     * @notice The Access Control identifier for the Global DenyList Funds Retire Role.
     *
     * An account with "GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE" can {burn} part or all funds of an address in the
     * Global DenyList.
     *
     * @dev This constant holds the hash of the string "GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE".
     */
    bytes32 public constant GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE = keccak256("GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE");

    /**
     * @notice The Access Control identifier for the Global Funds Rescue Role.
     *
     * An account with "GLOBAL_FUNDS_RESCUE_ROLE" can rescue funds from the participant contracts and the
     * Global Control contract.
     *
     * @dev This constant holds the hash of the string "GLOBAL_FUNDS_RESCUE_ROLE".
     */
    bytes32 public constant GLOBAL_FUNDS_RESCUE_ROLE = keccak256("GLOBAL_FUNDS_RESCUE_ROLE");

    /// State

    /**
     * @notice This is a dictionary that holds all the addresses that are in the Global DenyList.
     *
     * @dev In the mapping addresses that are in the Global DenyList, point to a "True" value.
     *
     * Key: account (address).
     * Value: state (bool).
     *
     */
    mapping(address => bool) private _globalDenyList;

    /**
     * @notice This is a dictionary that holds all the participating contracts in cohort of participating
     * smart contracts.
     *
     * @dev In this mapping, addresses that are in the Global Participant List point to a "True" value.
     *
     * Key: participant contract (address).
     * Value: state (bool).
     *
     */
    mapping(address => bool) private _globalParticipantList;

    /**
     * @notice This is a flag used to keep the status of the Global Pause.
     *
     * @dev If it is "True", Global Pause is active. If it is "False", Global Pause is inactive.
     */
    bool private _globalPauseIsActive;

    /// Events

    /**
     * @notice This is an event that logs the addition of a contract to the Participant List.
     * @param sender The (indexed) address that added the contract.
     * @param smartContract The address that was added to the Participant List.
     */
    event ParticipantAdded(address indexed sender, address smartContract);

    /**
     * @notice This is an event that logs the removal of a contract from the Participant List.
     * @param sender The (indexed) address that removed the contract.
     * @param smartContract The address that was removed from the Participant List.
     */
    event ParticipantRemoved(address indexed sender, address smartContract);

    /**
     * @notice This is an event that logs when Global Pause is activated.
     * @param sender The (indexed) address that activated Global Pause.
     */
    event GlobalPauseIssued(address indexed sender);

    /**
     * @notice This is an event that logs when Global Pause is deactivated.
     * @param sender The (indexed) address that deactivated Global Pause.
     */
    event GlobalPauseCleared(address indexed sender);

    /**
     * @notice This is an event that logs when an address is added to the Global DenyList.
     * @param sender The (indexed) address that added the address to the Global DenyList.
     * @param account The (indexed) address that was added to the Global DenyList.
     */
    event GlobalDenyListAddressAdded(address indexed sender, address indexed account);

    /**
     * @notice This is an event that logs when an address is removed from the Global DenyList.
     * @param sender The (indexed) address that removed the address from the Global DenyList.
     * @param account The (indexed) address that was removed from the Global DenyList.
     */
    event GlobalDenyListAddressRemoved(address indexed sender, address indexed account);

    /**
     * @notice This is an event that logs when funds are removed from a holder in the DenyList.
     * @param sender The (indexed) address of "GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE" holder which enacted the remove.
     * @param holder The (indexed) address of the asset holder.
     * @param asset The (indexed) asset address that was removed from the holder's balance.
     * @param amount The amount that was removed from the holder's balance.
     */
    event DenyListFundsERC20Retired(
        address indexed sender,
        address indexed holder,
        address indexed asset,
        uint256 amount
    );

    /// Modifiers

    /**
     * @notice Functions defined with this modifier confirm that the account address is not in the Global
     * DenyList before continuing.
     * @dev Reverts when the account is in the Global DenyList.
     * @param account The address of the account to be assessed.
     */
    modifier notInGlobalDenyList(address account) virtual {
        require(!isGlobalDenyListed(account), "Address is in Global DenyList");
        _;
    }

    /// Functions

    /**
     * @notice This function acts as the constructor of the contract.
     * @dev This function disables the initializers.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice This function initializes the Global Control contract by validating that the privileged addresses
     * are non-zero, initialising inherited libraries (for example the Access Control library), configuring role
     * grant privileges, and granting privileged roles.
     *
     * @dev Calling Conditions:
     *
     * - Can only be invoked once (controlled via the initializer modifier).
     * - Non-zero address `upgraderRoleAddress`.
     * - Non-zero address `pauserRoleAddress`.
     * - Non-zero address `accessControlAdminRoleAddress`.
     * - Non-zero address `participantAdminRoleAddress`.
     * - Non-zero address `globalPauseAdminRoleAddress`.
     * - Non-zero address `globalDenyListAdminRoleAddress`.
     * - Non-zero address `globalDenyListFundsRetireRoleAddress`.
     * - Non-zero address `globalFundsRescueRoleAddress`.
     *
     * The `upgraderRoleAddress` address will also receive the "DEFAULT_ADMIN_ROLE". An account with
     * "DEFAULT_ADMIN_ROLE" can manage all roles, unless {_setRoleAdmin} is used to appoint an alternate
     * admin role.
     *
     * @param upgraderRoleAddress The account to be granted the "UPGRADER_ROLE".
     * @param pauserRoleAddress The account to be granted the "PAUSER_ROLE".
     * @param accessControlAdminRoleAddress The account to be granted the "ACCESS_CONTROL_ADMIN_ROLE".
     * @param participantAdminRoleAddress The account to be granted the "PARTICIPANT_ADMIN_ROLE".
     * @param globalPauseAdminRoleAddress The account to be granted the "GLOBAL_PAUSE_ADMIN_ROLE".
     * @param globalDenyListAdminRoleAddress The account to be granted the "GLOBAL_DENYLIST_ADMIN_ROLE".
     * @param globalDenyListFundsRetireRoleAddress The account to be granted the "GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE".
     * @param globalFundsRescueRoleAddress The account to be granted the "GLOBAL_FUNDS_RESCUE_ROLE".
     */
    function initialize(
        address upgraderRoleAddress,
        address pauserRoleAddress,
        address accessControlAdminRoleAddress,
        address participantAdminRoleAddress,
        address globalPauseAdminRoleAddress,
        address globalDenyListAdminRoleAddress,
        address globalDenyListFundsRetireRoleAddress,
        address globalFundsRescueRoleAddress
    ) external initializer {
        if (upgraderRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("upgraderRoleAddress");
        }
        if (pauserRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("pauserRoleAddress");
        }
        if (accessControlAdminRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("accessControlAdminRoleAddress");
        }
        if (participantAdminRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("participantAdminRoleAddress");
        }
        if (globalPauseAdminRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("globalPauseAdminRoleAddress");
        }
        if (globalDenyListAdminRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("globalDenyListAdminRoleAddress");
        }
        if (globalDenyListFundsRetireRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("globalDenyListFundsRetireRoleAddress");
        }
        if (globalFundsRescueRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("globalFundsRescueRoleAddress");
        }

        // Init inherited dependencies.
        __UUPSUpgradeable_init();
        __Pausable_init();
        __FundsRescuableUpgradeableV1_init();
        __AccessControlEnumerable_init();

        // Grant access control admin role control.
        _setRoleAdmin(ACCESS_CONTROL_ADMIN_ROLE, UPGRADER_ROLE);
        _setRoleAdmin(PAUSER_ROLE, ACCESS_CONTROL_ADMIN_ROLE);

        _setRoleAdmin(PARTICIPANT_ADMIN_ROLE, ACCESS_CONTROL_ADMIN_ROLE);

        _setRoleAdmin(GLOBAL_PAUSE_ADMIN_ROLE, ACCESS_CONTROL_ADMIN_ROLE);
        _setRoleAdmin(GLOBAL_DENYLIST_ADMIN_ROLE, ACCESS_CONTROL_ADMIN_ROLE);
        _setRoleAdmin(GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE, ACCESS_CONTROL_ADMIN_ROLE);
        _setRoleAdmin(GLOBAL_FUNDS_RESCUE_ROLE, ACCESS_CONTROL_ADMIN_ROLE);

        // Grant roles.
        _grantRole(DEFAULT_ADMIN_ROLE, upgraderRoleAddress);
        _grantRole(UPGRADER_ROLE, upgraderRoleAddress);
        _grantRole(PAUSER_ROLE, pauserRoleAddress);
        _grantRole(ACCESS_CONTROL_ADMIN_ROLE, accessControlAdminRoleAddress);

        _grantRole(PARTICIPANT_ADMIN_ROLE, participantAdminRoleAddress);

        _grantRole(GLOBAL_PAUSE_ADMIN_ROLE, globalPauseAdminRoleAddress);
        _grantRole(GLOBAL_DENYLIST_ADMIN_ROLE, globalDenyListAdminRoleAddress);
        _grantRole(GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE, globalDenyListFundsRetireRoleAddress);
        _grantRole(GLOBAL_FUNDS_RESCUE_ROLE, globalFundsRescueRoleAddress);

        // Initialise state.
        _globalPauseIsActive = false;
    }

    /**
     * @notice This function is used to confirm whether an account is present on the Global Control DenyList.
     * @dev This function is a getter for the boolean value in Global Control DenyList for a particular address.
     * @param inspect The account address to be assessed.
     * @return The function returns a value of "True" if an address is present in the Global DenyList.
     */
    function isGlobalDenyListed(address inspect) public view returns (bool) {
        return _globalDenyList[inspect];
    }

    /**
     * @notice A function used to remove funds from a given address.
     *
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - `asset` should be a member of the Global Participant List.
     * - Global Pause is inactive.
     * - The sender of this function is not in Global DenyList. Participant smart contract DenyList not checked.
     * - An account must have the "GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE" to call this function.
     *
     * This function emits a {DenyListFundsERC20Retired} event, signalling that the funds
     * were removed from the specified address.
     *
     * @param participantSmartContract The asset that will be removed from the `account`.
     * @param account The address from which the funds are to be removed.
     * @param amount The amount of the `asset` that was removed from the `account` address.
     */
    function fundsRetireERC20(
        address participantSmartContract,
        address account,
        uint256 amount
    ) external whenNotPaused notInGlobalDenyList(_msgSender()) onlyRole(GLOBAL_DENYLIST_FUNDS_RETIRE_ROLE) {
        require(_globalParticipantList[participantSmartContract], "Asset is not a participant");
        IERC20DeniableUpgradeableV1 participantSmartContractInstance = IERC20DeniableUpgradeableV1(
            participantSmartContract
        );
        emit DenyListFundsERC20Retired(_msgSender(), account, participantSmartContract, amount);
        participantSmartContractInstance.fundsRetire(account, amount);
    }

    /**
     * @notice This function is used to rescue ETH from Global Control contract.
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - The sender is not listed in the Global DenyList.
     * - 'beneficiary' is not listed in the Global DenyList.
     * - `beneficiary` is non-zero address. (checked internally by {FundsRescuableUpgradeableV1.fundsRescueETH})
     * - `amount` is greater than 0. (checked internally by {FundsRescuableUpgradeableV1.fundsRescueETH})
     * - `amount` is less than or equal to the ETH balance of {GlobalControlV1}.
     *
     * Reverts if the sender does not have "GLOBAL_FUNDS_RESCUE_ROLE".
     *
     * This function emits a {FundsRescuedETH} event (as part of {FundsRescuableUpgradeableV1.fundsRescueETH}).
     *
     * This function could potentially call into an external contract. The controls for such interaction are listed
     * in {FundsRescuableUpgradeableV1.fundsRescueETH}.
     *
     * @param beneficiary The recipient of the rescued ETH funds.
     * @param amount The amount to be rescued.
     */
    function fundsRescueETH(
        address beneficiary,
        uint256 amount
    )
        public
        virtual
        override(FundsRescuableUpgradeableV1, IFundsRescuableUpgradeableV1)
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        notInGlobalDenyList(beneficiary)
        onlyRole(GLOBAL_FUNDS_RESCUE_ROLE)
    {
        super.fundsRescueETH(beneficiary, amount); // In {FundsRescuableUpgradeableV1}
    }

    /**
     * @notice This function is used to rescue ERC20 tokens from the Global Control contract.
     *
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - The sender is not listed in the Global DenyList.
     * - 'beneficiary' is not listed in the Global DenyList.
     * - 'asset is not listed in the Global DenyList.
     * - `beneficiary` is non-zero address. (checked internally by {FundsRescuableUpgradeableV1.fundsRescueERC20})
     * - `amount` is greater than 0. (checked internally by {FundsRescuableUpgradeableV1.fundsRescueERC20})
     * - `amount` is less than or equal to the `asset` balance of {GlobalControlV1}.
     *
     * Reverts if the sender does not have "GLOBAL_FUNDS_RESCUE_ROLE".
     *
     * This function emits a {FundsRescuedERC20} event (as part of {FundsRescuableUpgradeableV1.fundsRescueERC20}).
     *
     * This function could potentially call into an external contract. The controls for such interaction are listed
     * in {FundsRescuableUpgradeableV1.fundsRescueERC20}.
     *
     * @param beneficiary The recipient of the rescued ERC20 funds.
     * @param asset The contract address of the foreign asset which is to be rescued.
     * @param amount The amount to be rescued.
     */
    function fundsRescueERC20(
        address beneficiary,
        address asset,
        uint256 amount
    )
        public
        virtual
        override(FundsRescuableUpgradeableV1, IFundsRescuableUpgradeableV1)
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        notInGlobalDenyList(beneficiary)
        notInGlobalDenyList(asset)
        onlyRole(GLOBAL_FUNDS_RESCUE_ROLE)
    {
        super.fundsRescueERC20(beneficiary, asset, amount); // In {FundsRescuableUpgradeableV1}
    }

    /**
     * @notice This function is used to rescue ERC20 tokens from a participant contract.
     *
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - `participantSmartContract` should be a member of the Global Participant List.
     *
     * Reverts if the sender does not have "GLOBAL_FUNDS_RESCUE_ROLE".
     *
     * This function could potentially call into an external contract. To protect this contract against
     * unpredictable externalities, this method:
     *
     * - Limits interactions to only contracts that are in the Participant List.
     *
     * This function will fail if the Global Pause is active. However, the check is not implemented
     * at the Global Control contract level. The participant contract that implements {fundsRescueERC20}
     * should implement the check and revert if the Global Pause is active.
     *
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
    ) external virtual whenNotPaused notInGlobalDenyList(_msgSender()) onlyRole(GLOBAL_FUNDS_RESCUE_ROLE) {
        require(_globalParticipantList[participantSmartContract], "Not a participant");
        IFundsRescuableUpgradeableV1 participantSmartContractInstance = IFundsRescuableUpgradeableV1(
            participantSmartContract
        );
        participantSmartContractInstance.fundsRescueERC20(beneficiary, asset, amount);
    }

    /**
     * @notice This function is used to rescue ETH from a participant contract.
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - `participantSmartContract` should be a member of the Global Participant List.
     *
     * Reverts if the sender does not have "GLOBAL_FUNDS_RESCUE_ROLE".
     *
     * This function could potentially call into an external contract. To protect this contract against
     * unpredictable externalities, this method:
     *
     * - Limits interactions to only contracts that are in the Participant List.
     *
     * This function will fail if the Global Pause is active. However, the check is not implemented
     * at the Global Control contract level. The participant contract that implements {fundsRescueETH}
     * should implement the check and revert if the Global Pause is active.
     *
     * @param participantSmartContract The contract address from which the funds are extracted.
     * @param beneficiary The recipient of the rescued ETH funds.
     * @param amount The amount to be rescued.
     */
    function participantFundsRescueETH(
        address participantSmartContract,
        address beneficiary,
        uint256 amount
    ) external virtual whenNotPaused notInGlobalDenyList(_msgSender()) onlyRole(GLOBAL_FUNDS_RESCUE_ROLE) {
        require(_globalParticipantList[participantSmartContract], "Not a participant");
        IFundsRescuableUpgradeableV1 participantSmartContractInstance = IFundsRescuableUpgradeableV1(
            participantSmartContract
        );
        participantSmartContractInstance.fundsRescueETH(beneficiary, amount);
    }

    /**
     * @notice This is a function used to confirm whether the Global Pause is active.
     * @return The function returns a value of "True" if the Global Pause is active.
     */
    function isGlobalPaused() public view returns (bool) {
        return _globalPauseIsActive;
    }

    /**
     * @notice This is a function used to confirm that the contract is participating in the Stablecoin System,
     * governed by the Global Control contract.
     * @dev This function is a getter for the boolean value in Global Participant List for a particular address.
     * @param smartContract The address of the contract to be assessed.
     * @return This function returns a value of "True" if the `smartContract` address is registered
     * as a participant in the Global Control contract.
     */
    function isGlobalParticipant(address smartContract) external view returns (bool) {
        return _globalParticipantList[smartContract];
    }

    /**
     * @notice This is a function used to add a list of addresses to the Global Participant List.
     *
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - The sender is not listed in the Global DenyList.
     * - Can only be invoked by the address that has the role "PARTICIPANT_ADMIN_ROLE".
     * - Each member of the `participants` list should be a contract address.
     * - `participants` must have at least one non-zero address. Zero addresses won't be added to the Participant List.
     * - `participants` is not an empty array.
     * - `participants` list size is less than or equal to 100.
     *
     * This function emits a {ParticipantAdded} event for each address which was successfully added
     * to the Global Participant List.
     *
     * @param participants The list of accounts that will be added to the Global Participant List.
     */
    function globalParticipantListAdd(address[] calldata participants)
        external
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        onlyRole(PARTICIPANT_ADMIN_ROLE)
    {
        if (participants.length == 0) {
            revert LibErrorsV1.ZeroValuedParameter("participants");
        }
        require(participants.length <= 100, "List too long");
        bool hasNonZeroAddress = false;
        for (uint256 i = 0; i < participants.length; ) {
            if (participants[i] != address(0)) {
                hasNonZeroAddress = true;
                require(AddressUpgradeable.isContract(participants[i]), "Participant is not a contract");
                if (!_globalParticipantList[participants[i]]) {
                    _globalParticipantList[participants[i]] = true;
                    emit ParticipantAdded(_msgSender(), participants[i]);
                }
            }
            unchecked {
                i++;
            }
        }
        if (!hasNonZeroAddress) {
            revert LibErrorsV1.ZeroValuedParameter("participants");
        }
    }

    /**
     * @notice This is a function used to remove a list of addresses from the Global Participant List.
     * @dev Calling Conditions:
     *
     * - The sender is not listed in the Global DenyList.
     * - Can only be invoked by the address that has the role "PARTICIPANT_ADMIN_ROLE".
     * - {GlobalControlV1} is not paused.
     * - `participants` must have atleast one non-zero address.
     * - `participants` is not an empty array.
     * - `participants` list size is less than or equal to 100.
     *
     * This function emits a {ParticipantRemoved} event for each address which was successfully removed
     * from the Global Participant List.
     *
     * @param participants The list of accounts that will be removed from the Global Participant List.
     */
    function globalParticipantListRemove(address[] calldata participants)
        external
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        onlyRole(PARTICIPANT_ADMIN_ROLE)
    {
        if (participants.length == 0) {
            revert LibErrorsV1.ZeroValuedParameter("participants");
        }
        require(participants.length <= 100, "List too long");
        bool hasNonZeroAddress = false;
        for (uint256 i = 0; i < participants.length; ) {
            if (participants[i] != address(0)) {
                hasNonZeroAddress = true;
                if (_globalParticipantList[participants[i]]) {
                    _globalParticipantList[participants[i]] = false;
                    emit ParticipantRemoved(_msgSender(), participants[i]);
                }
            }
            unchecked {
                i++;
            }
        }
        if (!hasNonZeroAddress) {
            revert LibErrorsV1.ZeroValuedParameter("participants");
        }
    }

    /**
     * @notice This is a function used to add a list of addresses to the Global DenyList.
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - The sender is not listed in the DenyList.
     * - Can only be invoked by the address that has the role "GLOBAL_DENYLIST_ADMIN_ROLE".
     * - `accounts` must have at least one non-zero address. Zero addresses won't be added to the DenyList.
     * - `accounts` is not an empty array.
     * - `accounts` list size is less than or equal to 100.
     *
     * This function emits a {GlobalDenyListAddressAdded} event for each account which was successfully added to the
     * Global DenyList.
     *
     * @param accounts The list of accounts that will be added to the Global DenyList.
     */
    function globalDenyListAdd(address[] calldata accounts)
        external
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        onlyRole(GLOBAL_DENYLIST_ADMIN_ROLE)
    {
        if (accounts.length == 0) {
            revert LibErrorsV1.ZeroValuedParameter("accounts");
        }
        require(accounts.length <= 100, "List too long");
        bool hasNonZeroAddress = false;
        for (uint256 i = 0; i < accounts.length; ) {
            if (accounts[i] != address(0)) {
                hasNonZeroAddress = true;
                if (!_globalDenyList[accounts[i]]) {
                    _globalDenyList[accounts[i]] = true;
                    emit GlobalDenyListAddressAdded(_msgSender(), accounts[i]);
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
     * @notice This is a function used to remove a list of addresses from the Global DenyList.
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - The sender is not listed in the Global DenyList.
     * - Can only be invoked by the address that has the role "GLOBAL_DENYLIST_ADMIN_ROLE".
     * - `accounts` is a non-zero address.
     * - `accounts` is not an empty array.
     * - `accounts` list size is less than or equal to 100.
     *
     * This function emits a {GlobalDenyListAddressRemoved} event for each account which was successfully removed from
     * the Global DenyList.
     *
     * @param accounts A list of accounts that will be removed from the Global DenyList.
     */
    function globalDenyListRemove(address[] calldata accounts)
        external
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        onlyRole(GLOBAL_DENYLIST_ADMIN_ROLE)
    {
        if (accounts.length == 0) {
            revert LibErrorsV1.ZeroValuedParameter("accounts");
        }
        require(accounts.length <= 100, "List too long");
        bool hasNonZeroAddress = false;
        for (uint256 i = 0; i < accounts.length; ) {
            if (accounts[i] != address(0)) {
                hasNonZeroAddress = true;
                if (_globalDenyList[accounts[i]]) {
                    _globalDenyList[accounts[i]] = false;
                    emit GlobalDenyListAddressRemoved(_msgSender(), accounts[i]);
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
     * @notice This is a function used to pause the Global Control contract.
     * It also activates Global Pause when it is called.
     *
     * @dev Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "PAUSER_ROLE".
     * - The sender is not listed in the Global DenyList.
     * - {GlobalControlV1} is not paused.
     *
     * This function might emit a {Paused} event as part of {PausableUpgradeable._pause}.
     * This function emits a {GlobalPauseIssued} event(as part of {_globalPause}) indicating Global Pause is active.
     */
    function pause() external virtual notInGlobalDenyList(_msgSender()) onlyRole(PAUSER_ROLE) {
        _globalPause();
        _pause();
    }

    /**
     * @notice This is a function used to unpause the Global Control contract.
     *
     * Restoring full operation after a {pause} was enacted will, by design,
     * require calling {unpause} followed by {globalUnpause}.
     *
     * @dev Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "PAUSER_ROLE".
     * - The sender is not listed in the Global DenyList.
     * - {GlobalControlV1} is paused.
     */
    function unpause() external virtual notInGlobalDenyList(_msgSender()) onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice This is a function used to activate Global Pause.
     * This function does not pause the Global Control contract.
     *
     * @dev Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "GLOBAL_PAUSE_ADMIN_ROLE".
     * - {GloablControlV1} must not be paused.
     * - The sender is not listed in the Global DenyList.
     * - Global Pause must not be active.
     *
     * Uses the internal function {_globalPause} to set the `gloablPauseInEffect` boolean.
     *
     * This function emits a {GlobalPauseIssued} event(as part of {_globalPause}) indicating Global Pause is active.
     */
    function activateGlobalPause()
        external
        virtual
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        onlyRole(GLOBAL_PAUSE_ADMIN_ROLE)
    {
        require((!isGlobalPaused()), "Global Pause is already active");
        _globalPause();
    }

    /**
     * @notice This is a function used to deactivate Global Pause.
     * This function does not unpause the Global Control contract.
     *
     * @dev RCalling Conditions:
     *
     * - Can only be invoked by the address that has the role "GLOBAL_PAUSE_ADMIN_ROLE".
     * - {GloablControlV1} must not be paused.
     * - The sender is not listed in the Global DenyList.
     * - Global Pause must be active.
     *
     * Uses the internal function {_globalUnpause} to set the `gloablPauseInEffect` boolean.
     *
     * This function emits a {GlobalPauseCleared} event(as part of {_globalUnpause}) indicating Global Pause is inactive.
     */
    function deactivateGlobalPause()
        external
        virtual
        whenNotPaused
        notInGlobalDenyList(_msgSender())
        onlyRole(GLOBAL_PAUSE_ADMIN_ROLE)
    {
        require(_globalPauseIsActive, "Global Pause is inactive");
        _globalUnpause();
    }

    /**
     * @notice This function disables the OpenZeppelin inherited {renounceRole} function. Access Control roles
     * are controlled exclusively by "ACCESS_CONTROL_ADMIN_ROLE" and "UPGRADER_ROLE" role.
     */
    function renounceRole(bytes32, address)
        public
        virtual
        override(AccessControlUpgradeable, IAccessControlUpgradeable)
    {
        revert LibErrorsV1.OpenZeppelinFunctionDisabled();
    }

    /**
     * @notice This function allows the sender to grant a role to the `account` address.
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - The sender is not listed in the Global DenyList.
     * - Non-zero address `account`.
     *
     * This function might emit an {RoleGranted} event as part of {AccessControlUpgradeable._grantRole}.
     *
     * @param role The role that will be granted.
     * @param account The address that will receive the role.
     */
    function grantRole(bytes32 role, address account)
        public
        virtual
        override(AccessControlUpgradeable, IAccessControlUpgradeable)
        whenNotPaused
        notInGlobalDenyList(_msgSender())
    {
        if (account == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("account");
        }
        super.grantRole(role, account); // In {AccessControlUpgradeable}
    }

    /**
     * @notice This function allows the sender to revoke a role from the `account` address.
     * @dev Calling Conditions:
     *
     * - {GlobalControlV1} is not paused.
     * - The sender is not listed in the Global DenyList.
     * - Non-zero address `account`.
     *
     * This function might emit an {RoleRevoked} event as part of {AccessControlUpgradeable._revokeRole}.
     *
     * @param role The role that will be revoked.
     * @param account The address that will have its role revoked.
     */
    function revokeRole(bytes32 role, address account)
        public
        virtual
        override(AccessControlUpgradeable, IAccessControlUpgradeable)
        whenNotPaused
        notInGlobalDenyList(_msgSender())
    {
        if (account == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("account");
        }
        super.revokeRole(role, account); // In {AccessControlUpgradeable}
    }

    /**
     * @notice This is a function that sets the Global Pause to active.
     * @dev This function emits a {GlobalPauseIssued} event indicating Global Pause is active.
     */
    function _globalPause() internal virtual {
        _globalPauseIsActive = true;
        emit GlobalPauseIssued(_msgSender());
    }

    /**
     * @notice This is a function that sets the Global Pause to inactive.
     * @dev This function emits a {GlobalPauseCleared} event indicating Global Pause is inactive.
     */
    function _globalUnpause() internal virtual {
        _globalPauseIsActive = false;
        emit GlobalPauseCleared(_msgSender());
    }

    /**
     * @notice This is a function used to update the implementation address.
     * @dev Calling Conditions:
     *
     * - Only the "UPGRADER_ROLE" can execute.
     * - `newImplementation` is a non-zero address.
     *
     * @param newImplementation The address of the new logic contract.
     */
    /* solhint-disable no-empty-blocks */
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}
    /* solhint-enable no-empty-blocks */
}
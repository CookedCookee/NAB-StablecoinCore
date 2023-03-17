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
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";

import "./interface/IGlobalControlV1.sol";
import "./deny-list/ERC20DeniableUpgradeableV1.sol";
import "./mint-delegation/ERC20MintDelegatableUpgradeableV1.sol";
import "./lib/LibErrorsV1.sol";
import "./funds-rescue/FundsRescuableUpgradeableV1.sol";
import "./interface/IStablecoinCoreV1.sol";

/**
 * @title Stablecoin Core (V1)
 * @author National Australia Bank Limited
 * @notice The Stablecoin Core (V1) is the primary smart contract implementation of
 * the NAB Stablecoin Instances. Stablecoin Core is the implementation of all common logic
 * across the NAB cohort of Stablecoin Instances.
 *
 * The Stablecoin Core contract Role Based Access Control employs following roles:
 *
 *  - UPGRADER_ROLE
 *  - PAUSER_ROLE
 *  - ACCESS_CONTROL_ADMIN_ROLE
 *  - SUPPLY_DELEGATION_ADMIN_ROLE
 *  - MINT_ALLOWANCE_ADMIN_ROLE
 *  - MINTER_ROLE
 *  - BURNER_ROLE
 *  - DENYLIST_ADMIN_ROLE
 *  - DENYLIST_FUNDS_RETIRE_ROLE
 *  - METADATA_EDITOR_ROLE
 *
 * The following roles will not be granted at the time of deployment. They will be granted through
 * post-deployment transactions.
 *
 *  - SUPPLY_DELEGATION_ADMIN_ROLE
 *  - MINT_ALLOWANCE_ADMIN_ROLE
 *  - METADATA_EDITOR_ROLE
 *
 * The following states will be initialised with default empty values at the time of deployment. They will be set to
 * their operating state by post-deployment transactions.
 *
 *  - _issuer
 *  - _rank
 *  - _termsCid
 *
 * Furthermore {StablecoinCoreV1} honours incoming calls from the {GlobalControlV1} for the following functions:
 *
 *  - {fundRescueETH}.
 *  - {fundsRescueERC20}.
 *  - {fundsRetire}
 *
 * The Pause state is controlled locally and by honouring Global Control Pause. This has the effect that
 * the entire cohort of Stablecoin Instances can be paused centrally by enacting Global Pause or alternately individual
 * Stablecoin Instances can be paused for finer-grained control. This affords us the option of executing the following
 * illustrative workflow:
 *
 *  - Monitoring for and identifying an event/issue.
 *  - Pausing all Stablecoin Instances via Global Control.
 *  - Investigate and find the event/issue is limited to a single Stablecoin Instance.
 *  - Pause the specific Stablecoin Instance.
 *  - Unpause the Global Control Pause.
 *
 * In the Pause scenario above, the specific Stablecoin Instance will have been under Pause
 * from the initial Global Pause being issued through to the end without interruption.
 *
 * @dev DenyList and DenyList Funds Retire functionality is implemented in {ERC20DeniableUpgradeableV1}
 * and uses Access Control to get informed for the "DENYLIST_ADMIN_ROLE" and for the "DENYLIST_FUNDS_RETIRE_ROLE" roles.
 * With the union of the {StablecoinCoreV1} and {GlobalControlV1} DenyLists it is possible to deny one address
 * globally and limit another address on a specific Stablecoin Instance.
 *
 * Funds Rescue functionality is implemented in {StablecoinCoreV1} with
 * access controlled by the {GlobalControlV1}.
 *
 * {StablecoinCoreV1} implements delegated minting, allowing for multiple Minter & Burner address
 * pairs to be configured by the Supply Delegation Admin. The Mint Allowance Admin is
 * responsible for increasing and decreasing the minting allowance per pair. A Minter address
 * is granted the role of minting within the allowance and the Burner is granted the role of burning
 * any available funds in its address. There is no limit placed upon the number of Minter-Burner address pairs and
 * also no requirement for the two addresses to be the same. A Burner can be a part of multiple Minter-Burner pairs,
 * but a Minter can only be part of one Minter-Burner pair. This design allows for some decisions
 * to be controlled by configuration.
 *
 * * The {grantRole} and {revokeRole} functions MUST be configured here, to be able to dynamically grant
 * and revoke roles, where applicable. For example, the "MINTER_ROLE" and "BURNER_ROLE" roles
 * are NOT to be handled dynamically.
 *
 * The admin role for "MINTER_ROLE" and "BURNER_ROLE" roles must be "SUPPLY_DELEGATION_ADMIN_ROLE".
 * {ERC20MintDelegatableUpgradeableV1} will control the provision of such roles, although not via {grantRole} and
 * {revokeRole}. Instead, {_addSupplyControlPair} and {_removeSupplyControlPair} are to be used.
 */
contract StablecoinCoreV1 is
    Initializable,
    ERC20Upgradeable,
    PausableUpgradeable,
    AccessControlEnumerableUpgradeable,
    ERC20MintDelegatableUpgradeableV1,
    ERC20DeniableUpgradeableV1,
    ERC20PermitUpgradeable,
    FundsRescuableUpgradeableV1,
    UUPSUpgradeable,
    IStablecoinCoreV1
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
     * An account with "PAUSER_ROLE" can pause and unpause the Stablecoin Core contract.
     *
     * @dev This constant holds the hash of the string "PAUSER_ROLE".
     */
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @notice The Access Control identifier for the Access Control Admin Role.
     *
     * An account with "ACCESS_CONTROL_ADMIN_ROLE" can assign and revoke all the roles except itself, the
     * "UPGRADER_ROLE", "MINTER_ROLE" and "BURNER_ROLE".
     *
     * @dev This constant holds the hash of the string "ACCESS_CONTROL_ADMIN_ROLE".
     */
    bytes32 public constant ACCESS_CONTROL_ADMIN_ROLE = keccak256("ACCESS_CONTROL_ADMIN_ROLE");

    /**
     * @notice The Access Control identifier for the  Metadata Admin.
     *
     * An account with "METADATA_EDITOR_ROLE" can update the issuer, rank and terms of service Metadata.
     *
     * @dev This constant holds the hash of the string "METADATA_EDITOR_ROLE".
     */
    bytes32 public constant METADATA_EDITOR_ROLE = keccak256("METADATA_EDITOR_ROLE");

    /// State

    /**
     * @notice A field used to store text relating to the legal entity issuing the tokens.
     */
    string private _issuer;

    /**
     * @notice A field used to store information about the convertibility of the tokens back to fiat currency
     * in the event of a default.
     */
    string private _rank;

    /**
     * @notice A field used to store the link to the Content ID (CID) of a file containing the terms of service
     * for the Stablecoin Core.
     *
     * @dev This document is hosted on the InterPlanetary File System (IPFS).
     */
    string private _termsCid;

    /**
     * @notice This is a field used to describe the Global Control (V1) contract interface.
     * @dev It is initialised with the address of the GlobalControl proxy and can be used to check the Global
     * DenyList and if the Global Pause is active.
     */
    IGlobalControlV1 private _globalControlInstance;

    /// Events

    /**
     * @notice This is an event that logs whenever new tokens are minted.
     * @param sender The (indexed) address that minted the new tokens.
     * @param recipient The (indexed) address that received the new tokens.
     * @param amount The number of tokens minted.
     */
    event Mint(address indexed sender, address indexed recipient, uint256 amount);

    /**
     * @notice This is an event that logs whenever a Burner burns some tokens.
     * @param sender The (indexed) address that burned the tokens.
     * @param amount The number of tokens burned.
     */
    event Burn(address indexed sender, uint256 amount);

    /**
     * @notice This is an event that logs whenever the issuer is updated.
     * @param sender The (indexed) address that updates the issuer.
     * @param issuer The value of the new issuer.
     */
    event IssuerUpdated(address indexed sender, string issuer);

    /**
     * @notice This is an event that logs whenever the rank is updated.
     * @param sender The (indexed) address that updates the rank.
     * @param rank The value of the new rank.
     */

    event RankUpdated(address indexed sender, string rank);
    /**
     * @notice This is an event that logs whenever the terms CID is updated.
     * @param sender The (indexed) address that updates the terms CID.
     * @param termsCid The value of the new terms CID.
     */
    event TermsUpdated(address indexed sender, string termsCid);

    /// Modifiers

    /**
     * @notice This is a modifier used to confirm that the account is not in the Participant List.
     * @dev Reverts when the account address is on the Participant List.
     * @param account The address to be assessed.
     */
    modifier notInParticipantList(address account) virtual {
        require(!_globalControlInstance.isGlobalParticipant(account), "Address is in Participant List");
        _;
    }

    /**
     * @notice This is a modifier used to confirm that the sender is the Global Control (V1) contract.
     * @dev Reverts when the sender address is not the Global Control (V1) contract.
     */
    modifier onlyGlobalControl() virtual {
        require(_msgSender() == address(_globalControlInstance), "Not globalControlInstance");
        _;
    }

    /// Functions

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice This function initializes the Stablecoin Core (V1) by validating that the privileged addresses
     * are non-zero, initialising imported libraries (e.g. Pause), configuring role grant
     * privileges, and granting the privileged addresses their respective roles.
     *
     * @dev Calling Conditions:
     *
     * - Can only be invoked once (controlled via the initializer modifier).
     * - Non-empty string stablecoinName.
     * - Non-empty string stablecoinSymbol.
     * - Non-zero address globalControlContractAddress.
     * - Non-zero address upgraderRoleAddress.
     * - Non-zero address pauserRoleAddress.
     * - Non-zero address accessControlAdminRoleAddress.
     * - Non-zero address denyListAdminRoleAddress.
     * - Non-zero address denyListFundsRetireRoleAddress.
     *
     * The `upgraderRoleAddress` address will also receive the "DEFAULT_ADMIN_ROLE". An account with
     * "DEFAULT_ADMIN_ROLE" can manage all roles, unless {_setRoleAdmin} is used to appoint an alternate
     * admin role.
     *
     * @param stablecoinName String that holds the Stablecoin name.
     * @param stablecoinSymbol String that holds the Stablecoin symbol.
     * @param globalControlContract The address of the Global Control (V1) contract.
     * @param upgraderRoleAddress The account to be granted the "UPGRADER_ROLE".
     * @param pauserRoleAddress The account to be granted the "PAUSER_ROLE".
     * @param accessControlAdminRoleAddress The account to be granted the "ACCESS_CONTROL_ADMIN_ROLE".
     * @param denyListAdminRoleAddress The account to be granted the "DENYLIST_ADMIN_ROLE".
     * @param denyListFundsRetireRoleAddress The account to be granted the "DENYLIST_FUNDS_RETIRE_ROLE".
     */
    function initialize(
        string calldata stablecoinName,
        string calldata stablecoinSymbol,
        address globalControlContract,
        address upgraderRoleAddress,
        address pauserRoleAddress,
        address accessControlAdminRoleAddress,
        address denyListAdminRoleAddress,
        address denyListFundsRetireRoleAddress
    ) external initializer {
        if (bytes(stablecoinName).length == 0) {
            revert LibErrorsV1.ZeroValuedParameter("stablecoinName");
        }
        if (bytes(stablecoinSymbol).length == 0) {
            revert LibErrorsV1.ZeroValuedParameter("stablecoinSymbol");
        }
        if (upgraderRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("upgraderRoleAddress");
        }
        if (pauserRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("pauserRoleAddress");
        }
        if (accessControlAdminRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("accessControlAdminRoleAddress");
        }
        if (denyListAdminRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("denyListAdminRoleAddress");
        }
        if (denyListFundsRetireRoleAddress == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("denyListFundsRetireRoleAddress");
        }
        require(AddressUpgradeable.isContract(globalControlContract), "GlobalControl address is not a contract");

        // Init inherited dependencies
        __UUPSUpgradeable_init();
        __ERC20_init(stablecoinName, stablecoinSymbol);
        __ERC20Permit_init(stablecoinName);
        __ERC20Deniable_init(denyListAdminRoleAddress, denyListFundsRetireRoleAddress);
        __ERC20MintDelegatable_init();
        __Pausable_init();
        __FundsRescuableUpgradeableV1_init();
        __AccessControlEnumerable_init();

        _globalControlInstance = IGlobalControlV1(globalControlContract);

        // Grant access control admin role control
        _setRoleAdmin(ACCESS_CONTROL_ADMIN_ROLE, UPGRADER_ROLE);
        _setRoleAdmin(PAUSER_ROLE, ACCESS_CONTROL_ADMIN_ROLE);

        _setRoleAdmin(DENYLIST_ADMIN_ROLE, ACCESS_CONTROL_ADMIN_ROLE);
        _setRoleAdmin(DENYLIST_FUNDS_RETIRE_ROLE, ACCESS_CONTROL_ADMIN_ROLE);

        _setRoleAdmin(SUPPLY_DELEGATION_ADMIN_ROLE, ACCESS_CONTROL_ADMIN_ROLE);
        _setRoleAdmin(MINT_ALLOWANCE_ADMIN_ROLE, ACCESS_CONTROL_ADMIN_ROLE);
        _setRoleAdmin(METADATA_EDITOR_ROLE, ACCESS_CONTROL_ADMIN_ROLE);

        _setRoleAdmin(MINTER_ROLE, SUPPLY_DELEGATION_ADMIN_ROLE);
        _setRoleAdmin(BURNER_ROLE, SUPPLY_DELEGATION_ADMIN_ROLE);

        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, upgraderRoleAddress);
        _grantRole(UPGRADER_ROLE, upgraderRoleAddress);
        _grantRole(PAUSER_ROLE, pauserRoleAddress);
        _grantRole(ACCESS_CONTROL_ADMIN_ROLE, accessControlAdminRoleAddress);

        // Set an initial empty value for the Metadata state variables.
        _issuer = "";
        _rank = "";
        _termsCid = "";
    }

    /**
     * @notice This is a function used to pause the contract.
     * @dev Reverts if the sender does not have the "PAUSER_ROLE".
     *
     * Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "PAUSER_ROLE".
     * - The sender is not in DenyList.
     * - The sender is not in Global DenyList.
     * - {StablecoinCoreV1} is not paused.
     *
     * This function might emit an {Paused} event as part of {PausableUpgradeable._pause}.
     */
    function pause() external virtual onlyRole(PAUSER_ROLE) {
        _checkDenyListState(_msgSender());
        _pause();
    }

    /**
     * @notice This is a function used to unpause the contract.
     * @dev Reverts if the sender does not have the "PAUSER_ROLE".
     *
     * Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "PAUSER_ROLE".
     * - The sender is not in DenyList.
     * - The sender is not in Global DenyList.
     * - {StablecoinCoreV1} is paused.
     *
     * This function might emit an {Unpaused} event as part of {PausableUpgradeable._unpause}.
     */
    function unpause() external virtual onlyRole(PAUSER_ROLE) {
        _checkDenyListState(_msgSender());
        _unpause();
    }

    /**
     * @notice This is a function used to check if the contract is paused or not.
     * @return true if the contract is paused, and false otherwise.
     */
    function paused() public view override(IStablecoinCoreV1, PausableUpgradeable) returns (bool) {
        return super.paused(); // In {PausableUpgradeable}
    }

    /**
     * @notice This is a function used to get the issuer.
     * @return The name of the issuer.
     */
    function getIssuer() external view returns (string memory) {
        return _issuer;
    }

    /**
     * @notice This is a function used to get the rank.
     * @return The value of the rank.
     * */
    function getRank() external view returns (string memory) {
        return _rank;
    }

    /**
     * @notice This is a function used to get the link to the Content ID (CID).
     * @return The link to the id of the document containing terms and conditions.
     * */
    function getTermsCid() external view returns (string memory) {
        return _termsCid;
    }

    /**
     * @notice This is a function used to get the minting allowance of an address.
     * @param minter The address to get the minting allowance for.
     * @return The minting allowance delegated to the `minter`.
     */
    function getMintAllowance(
        address minter
    ) public view override(ERC20MintDelegatableUpgradeableV1, IStablecoinCoreV1) returns (uint256) {
        return super.getMintAllowance(minter); // In {ERC20MintDelegatableUpgradeableV1}
    }

    /**
     * @notice This is a function used to set the issuer.
     * @dev Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "METADATA_EDITOR_ROLE".
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - The sender is not in the DenyList.
     * - The sender is not in the Global DenyList.
     *
     * This function emits an {IssuerUpdated} event, signalling that the issuer was updated.
     *
     *  @param newIssuer The value of the new issuer.
     */
    function setIssuer(string calldata newIssuer) external onlyRole(METADATA_EDITOR_ROLE) {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        _issuer = newIssuer;
        emit IssuerUpdated(_msgSender(), newIssuer);
    }

    /**
     * @notice This is a function used to set the rank.
     * @dev Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "METADATA_EDITOR_ROLE".
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - The sender is not in the DenyList.
     * - The sender is not in the Global DenyList.
     *
     * This function emits a {RankUpdated} event, signalling that the rank was updated.
     *
     * @param newRank The value of the new rank.

     */
    function setRank(string calldata newRank) external onlyRole(METADATA_EDITOR_ROLE) {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        _rank = newRank;
        emit RankUpdated(_msgSender(), newRank);
    }

    /**
     * @notice A function used to set the link to the Content ID (CID) which contains terms of service
     * for Stablecoin Core (V1). This document is stored on the InterPlanetary File System (IPFS).
     *
     * @dev Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "METADATA_EDITOR_ROLE".
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - The sender is not in the DenyList.
     * - The sender is not in the Global DenyList.
     *
     * This function emits a {TermsUpdated} event, signalling that the terms CID was updated.
     *
     * @param newTermsCid The value of the new terms of service CID.
     */
    function setTermsCid(string calldata newTermsCid) external onlyRole(METADATA_EDITOR_ROLE) {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        _termsCid = newTermsCid;
        emit TermsUpdated(_msgSender(), newTermsCid);
    }

    /**
     * @notice This is a function used to remove funds from a given address.
     * @dev Calling Conditions:
     *
     * - The sender of this function must either have the "DENYLIST_FUNDS_RETIRE_ROLE" or be the
     * globalControl contract, which tells that the funds are retired by "GLOBAL_FUNDS_RETIRE_ROLE".
     * - {StablecoinCoreV1} is not paused. (checked internally by {_beforeTokenTransfer})
     * - Global Pause is inactive. (checked internally by {_beforeTokenTransfer})
     * - The sender is not in the DenyList.
     * - The sender is not in the Global DenyList.
     *
     * This function emits a {DenyListFundsRetired}, signalling  that the funds of the given address were removed.
     *
     * @param account The address for which the funds are to be removed.
     * @param amount The amount to be retired.
     */
    function fundsRetire(
        address account,
        uint256 amount
    ) public override(ERC20DeniableUpgradeableV1, IERC20DeniableUpgradeableV1) {
        if (!(hasRole(DENYLIST_FUNDS_RETIRE_ROLE, _msgSender()) || _msgSender() == address(_globalControlInstance))) {
            revert("Missing Role");
        }
        if (!isInDenyList(account) && !_globalControlInstance.isGlobalDenyListed(account)) {
            revert("Not in any DenyList");
        }
        super.fundsRetire(account, amount); // In {ERC20DeniableUpgradeableV1}
    }

    /**
     * @notice This is a function that adds a list of addresses to the DenyList.
     * The function can be called by the address which has the "DENYLIST_ADMIN_ROLE".
     *
     * @dev Reverts if the sender does not have the role "DENYLIST_ADMIN_ROLE".
     *
     * Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "DENYLIST_ADMIN_ROLE"
     * - The sender is not in the DenyList.
     * - The sender is not in the Global DenyList.
     *
     * This function emits a {DenyListAddressAdded} event(as a part of {ERC20DeniableUpgradeableV1.denyListAdd}) for each
     * account which was successfully added to the DenyList.
     *
     * @param accounts The list of addresses to be added in the DenyList.
     */
    function denyListAdd(
        address[] calldata accounts
    ) public override(ERC20DeniableUpgradeableV1, IERC20DeniableUpgradeableV1) {
        _checkDenyListState(_msgSender());
        super.denyListAdd(accounts); // In {ERC20DeniableUpgradeableV1}
    }

    /**
     * @notice This is a function that removes a list of addresses from the DenyList.
     * The function can be called by the address which has the "DENYLIST_ADMIN_ROLE".
     *
     * @dev Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "DENYLIST_ADMIN_ROLE"
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - The sender is not in the DenyList.
     * - The sender is not in the Global DenyList.
     *
     * This function emits a {DenyListAddressRemoved} event(as a part of {ERC20DeniableUpgradeableV1.denyListRemove}) for
     * each account which was successfully removed from the DenyList.
     *
     * @param accounts The list of addresses to be removed from DenyList.
     */
    function denyListRemove(
        address[] calldata accounts
    ) public override(ERC20DeniableUpgradeableV1, IERC20DeniableUpgradeableV1) {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        super.denyListRemove(accounts); // In {ERC20DeniableUpgradeableV1}
    }

    /**
     * @notice This is a function used to rescue foreign funds sent to the {StablecoinCoreV1} instance.
     * @dev Calling Conditions:
     *
     * - The sender must be the {GlobalControlV1} contract.
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - `amount` is greater than 0. (checked internally by {FundsRescuableUpgradeableV1.fundsRescueERC20})
     * - `beneficiary` is a non-zero address. (checked internally by {FundsRescuableUpgradeableV1.fundsRescueERC20})
     * - `asset` is a non-zero address (checked internally by {FundsRescuableUpgradeableV1.fundsRescueERC20})
     * - `amount` is less than or equal to the `asset` balance of {StablecoinCoreV1}.
     * - The sender is not in the DenyList.
     * - The sender is not in the Global DenyList.
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
    ) public virtual override(FundsRescuableUpgradeableV1, IFundsRescuableUpgradeableV1) onlyGlobalControl {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        _checkDenyListState(beneficiary);
        _checkDenyListState(asset);
        super.fundsRescueERC20(beneficiary, asset, amount); // In {FundsRescuableUpgradeableV1}
    }

    /**
     * @notice This is a function used to rescue ETH sent to the {StablecoinCoreV1} instance.
     * @dev Calling Conditions:
     *
     * - The sender must be the {GlobalControlV1} contract.
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - `amount` is greater than 0. (checked internally by {FundsRescuableUpgradeableV1.fundsRescueETH})
     * - `beneficiary` is a non-zero address. (checked internally by {FundsRescuableUpgradeableV1.fundsRescueETH})
     * - `amount` less than or equal to the ETH balance of {StablecoinCoreV1}.
     * - The sender is not in the DenyList.
     * - The sender is not in the Global DenyList.
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
    ) public virtual override(FundsRescuableUpgradeableV1, IFundsRescuableUpgradeableV1) onlyGlobalControl {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        _checkDenyListState(beneficiary);
        super.fundsRescueETH(beneficiary, amount); // In {FundsRescuableUpgradeableV1}
    }

    /**
     * @notice This is a function used to add a Minter-Burner pair.
     * @dev Reverts if the Minter-Burner pair was not successfully added.
     *
     * Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "SUPPLY_DELEGATION_ADMIN_ROLE"
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - `minter` and `burner` both are non-zero addresses.
     * - The sender is not in the DenyList.
     * - The sender is not in the Global DenyList.
     * - Both `minter` and `burner` must not be in the DenyList.
     * - Both `minter` and `burner` must not be in the Global DenyList.
     *
     * Minter and Burner can be the same address.
     *
     * This function emits a {SupplyDelegationPairAdded} event indicating that a Minter-Burner pair was added.
     *
     * @param minter The address of the pair to be granted the "MINTER_ROLE".
     * @param burner The address of the pair to be the "BURNER_ROLE".
     */
    function supplyDelegationPairAdd(address minter, address burner)
        external
        virtual
        onlyRole(SUPPLY_DELEGATION_ADMIN_ROLE)
    {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        _checkDenyListState(minter);
        _checkDenyListState(burner);
        _addSupplyControlPair(minter, burner);
        emit SupplyDelegationPairAdded(_msgSender(), minter, burner);
    }

    /**
     * @notice This is a function used to remove a Minter-Burner pair.
     * @dev Reverts if the Minter-Burner pair could not be successfully removed.
     *
     * Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "SUPPLY_DELEGATION_ADMIN_ROLE".
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - `minter` and `burner` both are non-zero addresses.
     * - `minter` and `burner` are a registered pair.
     * - The sender is not in the DenyList.
     * - The sender is not in the Global DenyList.
     *
     * This function emits a {SupplyDelegationPairRemoved} event, indicating that a Minter-Burner pair was removed.
     *
     * @param minter The address of the pair that will get its "MINTER_ROLE" revoked.
     * @param burner The address of the pair that will get its "BURNER_ROLE" revoked.
     */
    function supplyDelegationPairRemove(address minter, address burner)
        external
        onlyRole(SUPPLY_DELEGATION_ADMIN_ROLE)
    {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        uint256 minterAllowance = _getMintAllowance(minter);
        _removeSupplyControlPair(minter, burner);
        emit SupplyDelegationPairRemoved(_msgSender(), minter, burner, minterAllowance);
    }

    /**
     * @notice This is a function used to increase the minting allowance assigned to a minter.
     * @dev Extends {mintAllowanceIncrease} from DelegatedMintingUpgradeable.
     *
     * Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "MINT_ALLOWANCE_ADMIN_ROLE". (inherited check)
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - `minter` has the "MINTER_ROLE" role. (inherited check)
     * - `amount` is greater than 0. (inherited check)
     *
     * This function emits a {MintAllowanceIncreased} event, indicating that the Minter's minting allowance
     * was increased.
     *
     * @param minter The address that will get its minting allowance increased. This address must hold the
     * "MINTER_ROLE".
     * @param amount The amount that the minting allowance was increased by.
     */
    function mintAllowanceIncrease(
        address minter,
        uint256 amount
    ) public override(ERC20MintDelegatableUpgradeableV1, IStablecoinCoreV1) {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        _checkDenyListState(minter);
        super.mintAllowanceIncrease(minter, amount); // In {ERC20MintDelegatableUpgradeableV1}
    }

    /**
     * @notice This is a function used to decrease the minting allowance of a minter.
     * @dev Extends {mintAllowanceDecrease} from DelegatedMintingUpgradeable.
     *
     * Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "MINT_ALLOWANCE_ADMIN_ROLE". (inherited check)
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - `minter` is a non-zero address. (inherited check)
     * - `amount` is greater than 0. (inherited check)
     *
     * This function emits a {MintAllowanceDecreased} event, indicating that the Minter's minting allowance
     * was decreased.
     *
     * @param minter The address that will get its minting allowance decreased. This address must hold the
     * "MINTER_ROLE".
     * @param amount The amount that the minting allowance was decreased by.
     */
    function mintAllowanceDecrease(
        address minter,
        uint256 amount
    ) public override(ERC20MintDelegatableUpgradeableV1, IStablecoinCoreV1) {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        _checkDenyListState(minter);
        super.mintAllowanceDecrease(minter, amount); // In {ERC20MintDelegatableUpgradeableV1}
    }

    /**
     * @notice This is a function used to issue new tokens.
     * The sender will issue tokens to the `account` address.
     *
     * @dev Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "MINTER_ROLE".
     * - {StablecoinCoreV1} is not paused. (checked internally by {_beforeTokenTransfer})
     * - Global Pause is inactive. (checked internally by {_beforeTokenTransfer})
     * - The sender is not in the DenyList. (checked internally by {_beforeTokenTransfer})
     * - The sender is not in the Global DenyList. (checked internally by {_beforeTokenTransfer})
     * - The account is not in the DenyList. (checked internally by {_beforeTokenTransfer})
     * - The account is not in the Global DenyList. (checked internally by {_beforeTokenTransfer})
     * - The account is not in the Paticipant List.
     * - `account` is a non-zero address. (checked internally by {ERC20Upgradeable}.{_mint})
     * - `amount` is greater than 0. (checked internally by {_beforeTokenTransfer})
     *
     * This function emits a {Transfer} event as part of {ERC20Upgradeable._burn}.
     * This function emits a {Mint} event.
     *
     * @param account The address that will receive the issued tokens.
     * @param amount The number of tokens to be issued.
     */
    function mint(address account, uint256 amount)
        external
        virtual
        notInParticipantList(account)
        onlyRole(MINTER_ROLE)
    {
        _decreaseMintingAllowance(_msgSender(), amount);
        _mint(account, amount);
        emit Mint(_msgSender(), account, amount);
    }

    /**
     * @notice This is a function used to redeem tokens.
     * The sender can only redeem tokens from their balance.
     *
     * @dev Calling Conditions:
     *
     * - Can only be invoked by the address that has the role "BURNER_ROLE".
     * - {StablecoinCoreV1} is not paused. (checked internally by {_beforeTokenTransfer})
     * - Global Pause is inactive. (checked internally by {_beforeTokenTransfer})
     * - The sender is not in the DenyList. (checked internally by {_beforeTokenTransfer})
     * - The sender is not in the Global DenyList. (checked internally by {_beforeTokenTransfer})
     * - `amount` is greater than 0. (checked internally by {_beforeTokenTransfer})
     * - `amount` is not greater than sender's balance. (checked internally by {ERC20Upgradeable}.{_burn})
     *
     * This function emits a {Transfer} event as part of {ERC20Upgradeable._burn}.
     * This function emits a {Burn} event.
     *
     * @param amount The number of tokens that will be destroyed.
     */
    function burn(uint256 amount) public virtual onlyRole(BURNER_ROLE) {
        _burn(_msgSender(), amount);
        emit Burn(_msgSender(), amount);
    }

    /**
     * @notice This is a function used to set the token allowance
     * of a Spender using `owner` signed approval.
     *
     * @dev If the Spender already has a non-zero allowance by the same sender(approver),
     * the allowance will be set to reflect the new amount.
     *
     * Calling Conditions:
     *
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - The sender is not in DenyList.
     * - The sender is not in the Global DenyList.
     * - The `owner` is not in the DenyList.
     * - The `owner` is not in the Global DenyList.
     * - The `spender` is not in the DenyList.
     * - The `spender` is not in the Global DenyList.
     * - `spender` must be a non-zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - The signature must use `owner`'s current nonce
     *
     * This function emits an {Approval} event as part of {ERC20Upgradeable._approve}.
     *
     * @param owner The address that will sign the approval.
     * @param spender The address that will receive the approval.
     * @param value The allowance that will be approved.
     * @param deadline The expiry timestamp of the signature.
     * @param v The value used to confirm `owner` signature.
     * @param r The value used to confirm `owner` signature.
     * @param s The value used to confirm `owner` signature.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override(ERC20PermitUpgradeable, IERC20PermitUpgradeable) {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        _checkDenyListState(owner);
        _checkDenyListState(spender);
        super.permit(owner, spender, value, deadline, v, r, s); // In {ERC20PermitUpgradeable}
    }

    /**
     * @notice This is a function used to increase the allowance of a Spender.
     * A Spender can spend an approver's balance as per their allowance.
     *
     * @dev Calling Conditions:
     *
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - The sender is not in the DenyList.
     * - The sender is not in the Global DenyList.
     * - The `spender` is not in the DenyList.
     * - The `spender` is not in the Global DenyList.
     * - `spender` is a non-zero address.
     * - `amount` is greater than 0.
     *
     * This function emits an {Approval} event as part of {ERC20Upgradeable._approve}.
     *
     * If a `spender` has already been assigned a non-zero allowance by the same sender(approver) then
     * the allowance will be set to reflect the new amount.
     *
     * @param spender The address that will receive the spending allowance.
     * @param amount The latest value of allowance for the `spender`.
     * @return True if the allowance was updated successfully, reverts otherwise.
     */
    function approve(
        address spender,
        uint256 amount
    ) public virtual override(ERC20Upgradeable, IERC20Upgradeable) returns (bool) {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        _checkDenyListState(spender);
        return super.approve(spender, amount); // In {ERC20Upgradeable}
    }

    /**
     * @notice This is a function used to increase the allowance of a spender.
     * A spender can spend an approver's balance as per their allowance.
     * This function can be used instead of {approve}.
     *
     * @dev Calling Conditions:
     *
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - The sender is not in the DenyList.
     * - The sender is not in the Global DenyList.
     * - The `spender` is not in the DenyList.
     * - The `spender` is not in the Global DenyList.
     * - `spender` is a non-zero address.
     * - `amount` is greater than 0.
     *
     * This function emits an {Approval} event as part of {ERC20Upgradeable._approve}.
     *
     * If a `spender` has already been assigned a non-zero allowance by the same sender(approver) then
     * the allowance will be set to reflect the new amount.
     *
     * @param spender The address that will receive the spending allowance.
     * @param increment The number of tokens the `spender`'s allowance will be increased by.
     * @return True if the function was successful.
     */
    function increaseAllowance(
        address spender,
        uint256 increment
    ) public virtual override(ERC20Upgradeable, IStablecoinCoreV1) returns (bool) {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        _checkDenyListState(spender);
        return super.increaseAllowance(spender, increment); // In {ERC20Upgradeable}
    }

    /**
     * @notice This is a function used to decrease the allowance of a spender.
     *
     * @dev Calling Conditions:
     *
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - The sender is not in the DenyList.
     * - The sender is not in the Global DenyList.
     * - The `spender` is not in the DenyList.
     * - The `spender` is not in the Global DenyList.
     * - `spender` is a non-zero address.
     * - `amount` is greater than 0.
     * - Allowance to any spender cannot assume a negative value. The request is only processed if the requested
     * decrease is less than the current allowance.
     *
     * This function emits an {Approval} event as part of {ERC20Upgradeable._approve}.
     *
     * @param spender The address that will have its spending allowance decreased.
     * @param decrement The number of tokens the `spender`'s allowance will be decreased by.
     * @return True if the decrease in allowance was successful, reverts otherwise.
     */
    function decreaseAllowance(
        address spender,
        uint256 decrement
    ) public virtual override(ERC20Upgradeable, IStablecoinCoreV1) returns (bool) {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        _checkDenyListState(spender);
        return super.decreaseAllowance(spender, decrement); // In {ERC20Upgradeable}
    }

    /**
     * @notice This is a function used to transfer tokens from the sender to
     * the `recipient` address.
     *
     * @dev Calling Conditions:
     *
     * - StablecoinCore is not paused. (checked internally by {_beforeTokenTransfer})
     * - Global Pause is inactive. (checked internally by {_beforeTokenTransfer})
     * - The `sender` is not in the DenyList. (checked internally by {_beforeTokenTransfer})
     * - The `recipient` is not in the DenyList. (checked internally by {_beforeTokenTransfer})
     * - The sender is not in the Global DenyList. (checked internally by {_beforeTokenTransfer})
     * - The `recipient` is not in the Global DenyList. (checked internally by {_beforeTokenTransfer})
     * - The `recipient` is not in the Participant List.
     * - `recipient` is a non-zero address. (checked internally by {ERC20Upgradeable}.{_transfer})
     * - `amount` is greater than 0. (checked internally by {_beforeTokenTransfer})
     * - `amount` is not greater than sender's balance. (checked internally by {ERC20Upgradeable}.{_transfer})
     *
     * This function emits a {Transfer} event as part of {ERC20Upgradeable._transfer}.
     *
     * @param recipient The address that will receive the tokens.
     * @param amount The number of tokens that will be sent to the `recipient`.
     * @return True if the function was successful.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override(ERC20Upgradeable, IERC20Upgradeable) notInParticipantList(recipient) returns (bool) {
        return super.transfer(recipient, amount); // In {ERC20Upgradeable}
    }

    /**
     * @notice This is a function used to transfer tokens on behalf of the `from` address to
     * the `to` address.
     *
     * This function might emit an {Approval} event as part of {ERC20Upgradeable._approve}.
     * This function might emit a {Transfer} event as part of {ERC20Upgradeable._transfer}.
     *
     * @dev Calling Conditions:
     *
     * - StablecoinCore is not paused. (checked internally by {_beforeTokenTransfer})
     * - Global Pause is inactive. (checked internally by {_beforeTokenTransfer})
     * - The sender is not in DenyList. (checked internally by {_beforeTokenTransfer})
     * - The sender is not in Global DenyList. (checked internally by {_beforeTokenTransfer})
     * - The `from` is not in DenyList.
     * - The `from` is not in Global DenyList.
     * - The `to` is not in DenyList. (checked internally by {_beforeTokenTransfer})
     * - The `to` is not in Global DenyList. (checked internally by {_beforeTokenTransfer})
     * - The `to` is not in the Participant List.
     * - `from` is a non-zero address. (checked internally by {ERC20Upgradeable}.{_transfer})
     * - `to` is a non-zero address. (checked internally by {ERC20Upgradeable}.{_transfer})

     * - `amount` is greater than 0. (checked internally by {_beforeTokenTransfer})
     * - `amount` is not greater than `from`'s balance or sender's allowance. (checked internally
     *   by {ERC20Upgradeable}.{transferFrom})
     *
     * @param from The address that tokens will be transferred on behalf of.
     * @param to The address that will receive the tokens.
     * @param amount The number of tokens that will be sent to the `to` (recipient).
     * @return True if the function was successful.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override(ERC20Upgradeable, IERC20Upgradeable) notInParticipantList(to) returns (bool) {
        _checkDenyListState(from);
        return super.transferFrom(from, to, amount); // In {ERC20Upgradeable}
    }

    /**
     * @notice This is a function that allows the sender to grant a role to the `account` address.
     * @dev Granting "MINTER_ROLE" and "BURNER_ROLE" is restricted, as those roles
     * can only be granted via the {supplyDelegationPairAdd} function.
     *
     * Calling Conditions:
     *
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - The sender is not in DenyList.
     * - The sender is not in Global DenyList.
     * - Non-zero address `account`.
     *
     * This function might emit a {RoleGranted} event as part of {AccessControlUpgradeable._grantRole}.
     *
     * @param role The role that will be granted.
     * @param account The address that will received the role.
     */
    function grantRole(bytes32 role, address account)
        public
        override(AccessControlUpgradeable, IAccessControlUpgradeable)
    {
        _checkPausedState();
        _checkDenyListState(_msgSender());

        if (account == address(0)) {
            revert LibErrorsV1.ZeroValuedParameter("account");
        }
        if (role == MINTER_ROLE || role == BURNER_ROLE) {
            revert LibErrorsV1.OpenZeppelinFunctionDisabled();
        }
        super.grantRole(role, account); // In {AccessControlUpgradeable}
    }

    /**
     * @notice This function allows the sender to revoke a role from the `account` address.
     * @dev Revoking "MINTER_ROLE" and "BURNER_ROLE" is restricted, as those roles
     * can only be revoked via the {supplyDelegationPairRemove} function.
     *
     * Calling Conditions:
     *
     * - The sender is not in DenyList.
     * - The sender is not in Global DenyList.
     *
     * This function might emit a {RoleRevoked} event as part of {AccessControlUpgradeable._revokeRole}.
     *
     * @param role The role that will be revoked.
     * @param account The address that will have its role revoked.
     */
    function revokeRole(bytes32 role, address account)
        public
        override(AccessControlUpgradeable, IAccessControlUpgradeable)
    {
        _checkDenyListState(_msgSender());

        if (role == MINTER_ROLE || role == BURNER_ROLE) {
            revert LibErrorsV1.OpenZeppelinFunctionDisabled();
        }
        super.revokeRole(role, account); // In {AccessControlUpgradeable}
    }

    /**
     * @notice This function disables the OpenZeppelin inherited {renounceRole} function. Access Control roles
     * are controlled exclusively by "ACCESS_CONTROL_ADMIN_ROLE", "UPGRADER_ROLE"
     * and "SUPPLY_DELEGATION_ADMIN_ROLE" role.
     */
    function renounceRole(bytes32, address)
        public
        virtual
        override(AccessControlUpgradeable, IAccessControlUpgradeable)
    {
        revert LibErrorsV1.OpenZeppelinFunctionDisabled();
    }

    /**
     * @notice A function used to get the number of decimals.
     * @return A uint8 value representing the number of decimals.
     */
    function decimals() public pure virtual override(ERC20Upgradeable, IERC20MetadataUpgradeable) returns (uint8) {
        return 6;
    }

    /**
     * @notice This is a function that confirms that the sender has the "UPGRADER_ROLE".
     *
     * @dev Reverts when the sender does not have the "UPGRADER_ROLE".
     *
     * Calling Conditions:
     *
     * - Only the "UPGRADER_ROLE" can execute.
     *
     * @param newImplementation The address of the new logic contract.
     */
    /* solhint-disable no-empty-blocks */
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}

    /* solhint-enable no-empty-blocks */

    /**
     * @notice This function works as a middle layer and performs some checks before
     * it allows a transfer to operate.
     *
     * @dev A hook inherited from ERC20Upgradeable.
     *
     * The `from` parameter is not checked for DenyList or Global DenyList inclusion as part of this hook.
     * This serves Funds Retire scenarios (i.e. burning supply, where `from` is in either DenyList).
     *
     * This function performs the following checks, and reverts when not met:
     *
     * - {StablecoinCoreV1} is not paused.
     * - Global Pause is inactive.
     * - The sender is not in the DenyList.
     * - The sender is not in the Global DenyList.
     * - The `to` parameter is not in the DenyList.
     * - The `to` parameter is not in the Global DenyList.
     * - The `amount` is not zero.
     * @param to The address that receives the transfer `amount`.
     * @param amount The amount sent to the `to` address.
     */
    function _beforeTokenTransfer(
        address, // `from` parameter in ERC20Upgradeable , _beforeTokenTransfer
        address to,
        uint256 amount
    ) internal virtual override {
        _checkPausedState();
        _checkDenyListState(_msgSender());
        _checkDenyListState(to);
        if (amount == 0) {
            revert LibErrorsV1.ZeroValuedParameter("amount");
        }
    }

    /**
     * @notice This function is to be used to checkpoint the presence of `account` in the DenyList and
     * Global DenyList, which is controlled by the Global Control contract.
     *
     * @dev It performs an external call to the IGlobalControlV1 contract currently set as a state variable
     * to check the Global DenyList, before continuing with further logic.
     *
     * This function performs the following checks, and reverts when not met:
     *
     * - The `account` is not in the DenyList.
     * - The `account` is not in the Global DenyList.
     * @param account The address of the account to be assessed.
     */
    function _checkDenyListState(address account) internal view notInDenyList(account) {
        require(!_globalControlInstance.isGlobalDenyListed(account), "Address is in Global DenyList");
    }

    /**
     * @notice This function is to be used to checkpoint the StablecoinCore Pause (Pausable functionality) and
     * Global Pause (via Global Control) state, before continuing with further logic.
     *
     * @dev This function performs the following checks, and reverts when not met:
     *
     * - StablecoinCore is not paused.
     * - Global Pause is not in effect.
     */
    function _checkPausedState() internal view whenNotPaused {
        require(!_globalControlInstance.isGlobalPaused(), "Global Pause is active");
    }
}
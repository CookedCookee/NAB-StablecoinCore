const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers } = require("hardhat");

describe("NAB StablecoinCore Testing", function () {

    //////////////////////
    //Deploy Environment//
    //////////////////////

    async function deployEnvironment() {
        //Signers
        const [owner, addy0, addy1] = await ethers.getSigners();

        //Global control
        const GlobalControl = await ethers.getContractFactory("GlobalControlV1");
        const deployedGlobalControl = await GlobalControl.deploy();

        //Deploy AUDN
        const AUDN = await ethers.getContractFactory("StablecoinCoreV1");
        const deployedAUDNProxy = await upgrades.deployProxy(
            AUDN, 
            [
                "NAB AUD",
                "AUDN",
                deployedGlobalControl.address,
                owner.address,
                owner.address,
                owner.address,
                owner.address,
                owner.address
            ],
            {initializer: 'initialize'}
        );

        //Roles not already assigned
        const SUPPLY_DELEGATION_ADMIN_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("SUPPLY_DELEGATION_ADMIN_ROLE"));
        const MINT_ALLOWANCE_ADMIN_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINT_ALLOWANCE_ADMIN_ROLE"));
        const METADATA_EDITOR_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("METADATA_EDITOR_ROLE"));

        //Grant all roles to owner
        const return0a = await deployedAUDNProxy.grantRole(SUPPLY_DELEGATION_ADMIN_ROLE, owner.address);
        const return0b = await deployedAUDNProxy.grantRole(MINT_ALLOWANCE_ADMIN_ROLE, owner.address);
        const return0c = await deployedAUDNProxy.grantRole(METADATA_EDITOR_ROLE, owner.address);
        
        //Set delegation pair
        const return1 = await deployedAUDNProxy.supplyDelegationPairAdd(owner.address, owner.address);

        //Set allowance
        const return2 = await deployedAUDNProxy.mintAllowanceIncrease(owner.address, 10000000000);
        
        //Mint 10k
        const return3 = await deployedAUDNProxy.mint(owner.address, 10000000000);

        return { 
            owner,
            addy0,
            addy1,
            deployedAUDNProxy
        };
    }

    /////////////////////////
    //Testing Functionality//
    /////////////////////////

    describe("Testing Core Functionality", () => {
        it("Successfully test things", async function () {
            const { owner, addy0, addy1, deployedAUDNProxy } = await loadFixture(deployEnvironment);
        });
    });
});
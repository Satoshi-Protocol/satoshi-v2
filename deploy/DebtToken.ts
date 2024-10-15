import assert from 'assert'

import { type DeployFunction } from 'hardhat-deploy/types'
import { upgrades, ethers } from "hardhat";

const contractName = 'DebtToken'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    // This is an external deployment pulled in from @layerzerolabs/lz-evm-sdk-v2
    //
    // @layerzerolabs/toolbox-hardhat takes care of plugging in the external deployments
    // from @layerzerolabs packages based on the configuration in your hardhat config
    //
    // For this to work correctly, your network config must define an eid property
    // set to `EndpointId` as defined in @layerzerolabs/lz-definitions
    //
    // For example:
    //
    // networks: {
    //   fuji: {
    //     ...
    //     eid: EndpointId.AVALANCHE_V2_TESTNET
    //   }
    // }
    const endpointV2Deployment = await hre.deployments.get('EndpointV2')
    const DebtTokenFactory = await ethers.getContractFactory(contractName);

    const debtTokenProxy = await upgrades.deployProxy(DebtTokenFactory, ["satUSD.t","satUSD.t","0x0000000000000000000000000000000000000000", deployer], { initializer: "initialize" });



    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${debtTokenProxy.address}`)
}

deploy.tags = [contractName]

export default deploy

import assert from 'assert'

import { type DeployFunction } from 'hardhat-deploy/types'

const fs = require('fs')
const path = require('path')

interface Transaction {
    contractName: string
    transactionType: string
    contractAddress: string
}

const contractName = 'DebtToken'
const NAME = 'satUSD.t'
const SYMBOL = 'satUSD.t'

// get the address of the SatoshiXApp contract from broadcast(forge) recordings
const getSatoshiXAppAddress = (chainId: number, timestamp?: number) => {
    const time = timestamp ? `${timestamp}` : 'latest'

    const coreDevelopment = JSON.parse(
        fs.readFileSync(path.resolve(__dirname, `../broadcast/Deploy.s.sol/${chainId}/run-${time}.json`), 'utf8')
    )

    const txs = coreDevelopment.transactions
    const satoshiXAppTx: Transaction[] = txs.filter(
        (tx: Transaction) => tx.contractName === 'SatoshiXApp' && tx.transactionType == 'CREATE'
    )

    return satoshiXAppTx[0].contractAddress
}

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    //const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    const satoshiXAppAddr = getSatoshiXAppAddress(hre.network.config.chainId!)

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

    const endpointV2Deployment = await deployments.get('EndpointV2')
    const DebtTokenFactory = await hre.ethers.getContractFactory(contractName)

    const debtTokenProxy = await hre.upgrades.deployProxy(DebtTokenFactory, [NAME, SYMBOL, satoshiXAppAddr, deployer], {
        initializer: 'initialize',
        constructorArgs: [endpointV2Deployment.address],
    })

    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${debtTokenProxy.address}`)
}

deploy.tags = [contractName]

export default deploy

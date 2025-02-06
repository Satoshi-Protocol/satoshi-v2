import { type DeployFunction } from 'hardhat-deploy/types'

const fs = require('fs')
const path = require('path')

interface Transaction {
    contractName: string
    transactionType: string
    contractAddress: string
    arguments: string[]
}

const contractName = 'DebtTokenWithLz'

// get the contract address from broadcast(forge) recordings
const getContractAddress = (deployFile: string, contract: string, chainId: number, timestamp?: number) => {
    const time = timestamp ? `${timestamp}` : 'latest'
    const development = JSON.parse(
        fs.readFileSync(path.resolve(__dirname, `../broadcast/${deployFile}.s.sol/${chainId}/run-${time}.json`), 'utf8')
    )

    const txs = development.transactions
    const targetTx: Transaction[] = txs.filter(
        (tx: Transaction) => tx.contractName === contract && tx.transactionType == 'CREATE'
    )

    return targetTx[0].contractAddress
}

const getProxyAddress = (deployFile: string, contract: string, impl: string, chainId: number, timestamp?: number) => {
    const time = timestamp ? `${timestamp}` : 'latest'
    const development = JSON.parse(
        fs.readFileSync(path.resolve(__dirname, `../broadcast/${deployFile}.s.sol/${chainId}/run-${time}.json`), 'utf8')
    )

    const txs = development.transactions
    const targetTx: Transaction[] = txs.filter(
        (tx: Transaction) => tx.contractName === contract && tx.transactionType === 'CREATE'
    )
    const res = targetTx.filter((tx) => tx.arguments[0].toLocaleLowerCase() === impl)

    return res[0].contractAddress
}

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { save } = deployments
    const { deployer } = await getNamedAccounts()

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    const artifact = await deployments.getExtendedArtifact('DebtTokenWithLz')
    const debtImpl = getContractAddress('Deploy', 'DebtTokenWithLz', hre.network.config.chainId!)
    console.log(`DebtTokenWithLz implementation address: ${debtImpl}`)
    const debtTokenAddr = getProxyAddress('Deploy', 'ERC1967Proxy', debtImpl, hre.network.config.chainId!)

    const proxyDeployments = {
        address: debtTokenAddr,
        ...artifact,
    }

    // save the contract data to the deployments folder
    await save('DebtTokenWithLz', proxyDeployments)
}

deploy.tags = [contractName]

export default deploy

import { type DeployFunction } from 'hardhat-deploy/types'

const fs = require('fs')
const path = require('path')

interface Transaction {
    contractName: string
    transactionType: string
    contractAddress: string
}

const contractName = 'DebtToken'

// get the contract address from broadcast(forge) recordings
const getContractAddress = (deployFile: string, contract: string, chainId: number, timestamp?: number) => {
    const time = timestamp ? `${timestamp}` : 'latest'

    const coreDevelopment = JSON.parse(
        fs.readFileSync(path.resolve(__dirname, `../broadcast/${deployFile}.s.sol/${chainId}/run-${time}.json`), 'utf8')
    )

    const txs = coreDevelopment.transactions
    const targetTx: Transaction[] = txs.filter(
        (tx: Transaction) => tx.contractName === contract && tx.transactionType == 'CREATE'
    )

    return targetTx[0].contractAddress
}

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { save } = deployments
    const { deployer } = await getNamedAccounts()

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    const artifact = await deployments.getExtendedArtifact('DebtToken')
    const debtTokenAddr = getContractAddress('DeployDebtToken', 'ERC1967Proxy', hre.network.config.chainId!)

    const proxyDeployments = {
        address: debtTokenAddr,
        ...artifact,
    }

    // save the contract data to the deployments folder
    await save('DebtToken', proxyDeployments)
}

deploy.tags = [contractName]

export default deploy

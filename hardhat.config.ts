// Get the environment configuration from .env file
//
// To make use of automatic environment setup:
// - Duplicate .env.example file and name it .env
// - Fill in the environment variables
import 'dotenv/config'

import 'hardhat-deploy'
import 'hardhat-contract-sizer'
import '@nomiclabs/hardhat-ethers'
import '@layerzerolabs/toolbox-hardhat'
import '@openzeppelin/hardhat-upgrades'
import '@nomicfoundation/hardhat-foundry'

// Add a blank line between import groups
import { HardhatUserConfig, HttpNetworkAccountsUserConfig } from 'hardhat/types'

import { EndpointId } from '@layerzerolabs/lz-definitions'

// Set your preferred authentication method
//
// If you prefer using a mnemonic, set a MNEMONIC environment variable
// to a valid mnemonic
const MNEMONIC = process.env.MNEMONIC

// If you prefer to be authenticated using a private key, set a PRIVATE_KEY environment variable
const PRIVATE_KEY = process.env.DEPLOYMENT_PRIVATE_KEY

const accounts: HttpNetworkAccountsUserConfig | undefined = MNEMONIC
    ? { mnemonic: MNEMONIC }
    : PRIVATE_KEY
      ? [PRIVATE_KEY]
      : undefined

if (accounts == null) {
    console.warn(
        'Could not find MNEMONIC or PRIVATE_KEY environment variables. It will not be possible to execute transactions in your example.'
    )
}

const config: HardhatUserConfig = {
    paths: {
        cache: 'cache/hardhat',
        sources: 'src',
    },
    solidity: {
        compilers: [
            {
                version: '0.8.20',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },

    networks: {
        holesky: {
            eid: EndpointId.HOLESKY_V2_TESTNET,
            url: process.env.RPC_URL_HOLESKY || 'https://ethereum-holesky-rpc.publicnode.com',
            chainId: 17000,
            accounts,
        },
        'sepolia-testnet': {
            eid: EndpointId.SEPOLIA_V2_TESTNET,
            url: process.env.RPC_URL_SEPOLIA || 'https://rpc.sepolia.org/',
            chainId: 11155111,
            accounts,
        },
        'arbitrum-sepolia': {
            eid: EndpointId.ARBITRUM_V2_TESTNET, // from @layerzerolabs/lz-definitions
            url: process.env.RPC_URL_ARBITRUM_SEPOLIA || 'https://arbitrum-sepolia.gateway.tenderly.co',
            chainId: 421614,
            accounts,
        },
        'base-sepolia': {
            eid: EndpointId.BASE_V2_TESTNET, // from @layerzerolabs/lz-definitions
            url: process.env.RPC_URL_BASE_SEPOLIA || 'https://base-sepolia.gateway.tenderly.co',
            accounts,
        },
        'avalanche-testnet': {
            eid: EndpointId.AVALANCHE_V2_TESTNET,
            url: process.env.RPC_URL_FUJI || 'https://rpc.ankr.com/avalanche_fuji',
            accounts,
        },
        'amoy-testnet': {
            eid: EndpointId.AMOY_V2_TESTNET,
            url: process.env.RPC_URL_AMOY || 'https://polygon-amoy-bor-rpc.publicnode.com',
            accounts,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0, // wallet address of index[0], of the mnemonic in .env
        },
    },
}

export default config

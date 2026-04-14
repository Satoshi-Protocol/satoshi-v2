require('dotenv').config();

const COMMON_DEPLOY_SETUP = {
    enabled: false,
    // Keep empty to fallback to deployer account in migration.
    owner: '',
    guardian: '',
    feeReceiver: '',
    wethAddress: '',
    // Empty means deploy DebtToken (without LZ endpoint).
    lzEndpoint: '',

    // Reference: script/DeploySetupConfig.s.sol
    debtTokenName: 'Satoshi Stablecoin V2',
    debtTokenSymbol: 'satUSD',
    minNetDebt: '10000000000000000000',
    debtGasCompensation: '2000000000000000000',
    spClaimStartTime: '4294967295',
    spAllocation: '0',
    spRewardRate: '0',

    preflight: {
        enabled: true,
        minTrx: 1000,
    },
};

const COMMON_DEPLOY_INSTANCE = {
    enabled: false,
    // If empty, read from tron/deployments/<network>.deploysetup.json
    satoshiXApp: '',
    rewardManager: '',
    vaultManager: '',
    communityIssuance: '',

    // Required when enabled=true
    collateralAddress: 'TYcwYsfpYsa8jtQ2GzacVLpCB3AQuxyySe',
    priceFeedAddress: 'TZHim86dG3vmETDjwZ893Qie1snm1Km8e3',

    // Reference: script/DeployInstanceConfig.sol
    MCR: '1700000000000000000',
    minuteDecayFactor: '999037758833783500',
    redemptionFeeFloor: '5000000000000000',
    maxRedemptionFee: '50000000000000000',
    borrowingFeeFloor: '5000000000000000',
    maxBorrowingFee: '50000000000000000',
    interestRateInBps: '0',
    maxDebt: '1000000000000000000000000000',
    rewardRate: '0',
    oshiAllocation: '0',
    claimStartTime: '4294967295',
    retainPercentage: '0',
    refillPercentage: '0',
};

const COMMON_DEPLOY_ORACLE_MOCK = {
    enabled: false,
    // Constructor args for test/mocks/OracleMock.sol
    decimals: 18,
    version: '1',
    // Seed answer used in updateRoundData right after deployment.
    initialAnswer: '100000000000000000000000',
    // Must be > 120 (calls updateMaxTimeThreshold after deploy).
    maxTimeThreshold: '86400',
};

const COMMON_DEPLOY_ERC20_MOCK = {
    enabled: false,
    // Constructor args for test/mocks/ERC20Mock.sol
    name: 'ERC20 Mock',
    symbol: 'MCK',
    // Optional post-deploy mint.
    initialMint: '0',
    // Leave empty to mint to deployer.
    mintTo: '',
};

const COMMON_DEPLOY_PRICE_FEED_CHAINLINK = {
    enabled: false,
    // Chainlink AggregatorV3 source. Accepts T... / 41... / 0x... formats.
    sourceAddress: 'TJR9eco3cKMt4avk7naok9TbKMxY51izZM',
    // Must be > 120. Reference: script/priceFeed/DeployPriceFeedChainlink.s.sol
    maxTimeThreshold: '86700',
    // Optional post-deploy validation calls (fetchPrice/fetchPriceUnsafe/decimals).
    validateAfterDeploy: true,
};

const COMMON_SET_NYM_ASSET_CONFIG = {
    enabled: true,
    // If empty, read satoshiXApp from tron/deployments/<network>.deploysetup.json
    satoshiXApp: '',
    // Address of the asset to configure. Accepts T... / 41... / 0x... formats.
    assetAddress: 'TYcwYsfpYsa8jtQ2GzacVLpCB3AQuxyySe',
    // Fee for swapIn (basis points, e.g. 100 = 1%). 0 = no fee.
    feeIn: '100',
    // Fee for swapOut (basis points, e.g. 100 = 1%). 0 = no fee.
    feeOut: '0',
    // Maximum total debtToken that can be minted via this asset (18 decimals).
    debtTokenMintCap: '1000000000000000000000000000',
    // Maximum debtToken mintable per day (18 decimals).
    dailyDebtTokenMintCap: '1000000000000000000000000',
    // Waiting period (in seconds) between scheduleSwapOut and withdraw.
    swapWaitingPeriod: '3600',
    // Maximum acceptable oracle price (18 decimals, e.g. 1.05e18).
    maxPrice: '1050000000000000000',
    // Minimum acceptable oracle price (18 decimals, e.g. 0.95e18).
    minPrice: '950000000000000000',
    // Whether the contract uses an oracle for this asset.
    isUsingOracle: false,
};

module.exports = {
    networks: {
        nile: {
            privateKey: process.env.TRON_PRIVATE_KEY_NILE || process.env.TRON_PRIVATE_KEY || '',
            // Override when DNS/network policy blocks default public RPC.
            fullHost: process.env.TRON_FULL_HOST_NILE || process.env.TRON_FULL_HOST || 'https://nile.trongrid.io',
            feeLimit: 5_000_000_000,
            userFeePercentage: 100,
            deploySetup: { ...COMMON_DEPLOY_SETUP },
            deployInstance: { ...COMMON_DEPLOY_INSTANCE },
            deployPriceFeedChainlink: { ...COMMON_DEPLOY_PRICE_FEED_CHAINLINK },
            deployOracleMock: { ...COMMON_DEPLOY_ORACLE_MOCK },
            deployERC20Mock: { ...COMMON_DEPLOY_ERC20_MOCK },
            setNYMAssetConfig: { ...COMMON_SET_NYM_ASSET_CONFIG },
        },
        shasta: {
            privateKey: process.env.TRON_PRIVATE_KEY_SHASTA || process.env.TRON_PRIVATE_KEY || '',
            fullHost:
                process.env.TRON_FULL_HOST_SHASTA || process.env.TRON_FULL_HOST || 'https://api.shasta.trongrid.io',
            feeLimit: 5_000_000_000,
            userFeePercentage: 100,
            deploySetup: { ...COMMON_DEPLOY_SETUP },
            deployInstance: { ...COMMON_DEPLOY_INSTANCE },
            deployPriceFeedChainlink: { ...COMMON_DEPLOY_PRICE_FEED_CHAINLINK },
            deployOracleMock: { ...COMMON_DEPLOY_ORACLE_MOCK },
            deployERC20Mock: { ...COMMON_DEPLOY_ERC20_MOCK },
            setNYMAssetConfig: { ...COMMON_SET_NYM_ASSET_CONFIG },
        },
        mainnet: {
            privateKey: process.env.TRON_PRIVATE_KEY_MAINNET || process.env.TRON_PRIVATE_KEY || '',
            fullHost: process.env.TRON_FULL_HOST_MAINNET || process.env.TRON_FULL_HOST || 'https://api.trongrid.io',
            feeLimit: 5_000_000_000,
            userFeePercentage: 100,
            deploySetup: { ...COMMON_DEPLOY_SETUP },
            deployInstance: { ...COMMON_DEPLOY_INSTANCE },
            deployPriceFeedChainlink: { ...COMMON_DEPLOY_PRICE_FEED_CHAINLINK },
            deployOracleMock: { ...COMMON_DEPLOY_ORACLE_MOCK },
            deployERC20Mock: { ...COMMON_DEPLOY_ERC20_MOCK },
            setNYMAssetConfig: { ...COMMON_SET_NYM_ASSET_CONFIG },
        },
    },
};

const deployConfig = require('../config/deployConfig');
const addressUtils = require('./utils/address');
const { uintString, readDeploySetupOutput } = require('./utils/config');

const NexusYieldManagerFacet = artifacts.require('NexusYieldManagerFacet');
const SatoshiXApp = artifacts.require('SatoshiXApp');

const toTronHexAddress = (value) => addressUtils.toTronHexAddress(value, tronWeb);
const toTronBase58Address = (value) => addressUtils.toTronBase58Address(value, tronWeb);

module.exports = function (deployer, network, fromOrAccounts) {
    return deployer.then(async () => {
        // Inject TronGrid API key into existing providers (tronbox ignores headers config)
        const _apiKey = process.env.TRON_PRO_API_KEY || '';
        if (_apiKey) {
            const h = { 'TRON-PRO-API-KEY': _apiKey };
            for (const node of [tronWeb.fullNode, tronWeb.solidityNode, tronWeb.eventServer]) {
                if (node && node.instance) Object.assign(node.instance.defaults.headers, h);
                if (node) node.headers = h;
            }
        }

        let step = 1;
        const done = (message) => {
            console.log(`[tron][step ${step}] ${message}`);
            step += 1;
        };

        const networkCfg = (deployConfig.networks || {})[network];
        if (!networkCfg) {
            throw new Error(`[tron] missing network config for "${network}" in tron/config/deployConfig.js`);
        }
        const cfg = networkCfg.setNYMAssetConfig || {};
        if (!cfg.enabled) {
            console.log('[tron] Skip setNYMAssetConfig (set setNYMAssetConfig.enabled=true to enable).');
            return;
        }

        const deployerAccount = Array.isArray(fromOrAccounts)
            ? fromOrAccounts[0]
            : typeof fromOrAccounts === 'string'
              ? fromOrAccounts
              : networkCfg.deployer;
        const deployerBase58 = toTronBase58Address(toTronHexAddress(deployerAccount));
        const txOpts = { from: deployerBase58 };
        const OWNER_ROLE = tronWeb.sha3('OWNER_ROLE');
        done(`loaded network config, deployer=${deployerBase58}`);

        // Resolve satoshiXApp address (config first, then deploysetup output).
        const deploySetupOut = readDeploySetupOutput(network) || {};
        const satoshiXApp = toTronHexAddress(cfg.satoshiXApp || deploySetupOut.satoshiXApp || '');
        if (!satoshiXApp) {
            throw new Error('[tron] setNYMAssetConfig requires satoshiXApp address (from config or deploysetup.json).');
        }
        done(`resolved satoshiXApp=${toTronBase58Address(satoshiXApp)}`);

        // Resolve asset address.
        if (!cfg.assetAddress) {
            throw new Error('[tron] setNYMAssetConfig.assetAddress is required.');
        }
        const assetAddress = toTronHexAddress(cfg.assetAddress);
        done(`resolved assetAddress=${toTronBase58Address(assetAddress)}`);

        // Validate deployer has OWNER_ROLE.
        const satoshiXAppContract = await SatoshiXApp.at(satoshiXApp);
        const hasOwnerRole = await satoshiXAppContract.hasRole(OWNER_ROLE, deployerBase58);
        if (!hasOwnerRole) {
            throw new Error(
                `[tron] deployer ${deployerBase58} does not have OWNER_ROLE on ${toTronBase58Address(satoshiXApp)}`
            );
        }
        done(`confirmed OWNER_ROLE for deployer`);

        // Build AssetConfig tuple.
        // Note: debtTokenMinted is ignored by setAssetConfig; pass 0.
        const assetConfig = [
            uintString(cfg.feeIn, '0', 'feeIn', 'setNYMAssetConfig'),
            uintString(cfg.feeOut, '0', 'feeOut', 'setNYMAssetConfig'),
            uintString(cfg.debtTokenMintCap, '1000000000000000000000000000', 'debtTokenMintCap', 'setNYMAssetConfig'),
            uintString(
                cfg.dailyDebtTokenMintCap,
                '1000000000000000000000000',
                'dailyDebtTokenMintCap',
                'setNYMAssetConfig'
            ),
            '0', // debtTokenMinted — skipped by setAssetConfig
            uintString(cfg.swapWaitingPeriod, '0', 'swapWaitingPeriod', 'setNYMAssetConfig'),
            uintString(cfg.maxPrice, '1050000000000000000', 'maxPrice', 'setNYMAssetConfig'),
            uintString(cfg.minPrice, '950000000000000000', 'minPrice', 'setNYMAssetConfig'),
            cfg.isUsingOracle === true || cfg.isUsingOracle === 'true',
        ];
        done('built AssetConfig tuple');

        // Call setAssetConfig.
        const nymFacet = await NexusYieldManagerFacet.at(satoshiXApp);
        const tx = await nymFacet.setAssetConfig(assetAddress, assetConfig, txOpts);
        console.log(`[tron][step ${step}] setAssetConfig tx: ${tx.txID || tx.transaction?.txID || JSON.stringify(tx)}`);
        step += 1;

        // Print summary.
        console.log('\n[tron] NYM asset config set successfully:');
        console.log(`  satoshiXApp      : ${toTronBase58Address(satoshiXApp)}`);
        console.log(`  assetAddress     : ${toTronBase58Address(assetAddress)}`);
        console.log(`  feeIn            : ${assetConfig[0]}`);
        console.log(`  feeOut           : ${assetConfig[1]}`);
        console.log(`  debtTokenMintCap : ${assetConfig[2]}`);
        console.log(`  dailyMintCap     : ${assetConfig[3]}`);
        console.log(`  swapWaitingPeriod: ${assetConfig[5]}`);
        console.log(`  maxPrice         : ${assetConfig[6]}`);
        console.log(`  minPrice         : ${assetConfig[7]}`);
        console.log(`  isUsingOracle    : ${assetConfig[8]}`);
        done('done');
    });
};

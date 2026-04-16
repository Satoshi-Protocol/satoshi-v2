const fs = require('fs');
const path = require('path');
const deployConfig = require('../config/deployConfig');
const addressUtils = require('./utils/address');

const PriceFeedChainlink = artifacts.require('PriceFeedChainlink');
const toTronHexAddress = (value) => addressUtils.toTronHexAddress(value, tronWeb);
const toTronBase58Address = (value) => addressUtils.toTronBase58Address(value, tronWeb);
const normalizeOutputAddresses = (value) => addressUtils.normalizeOutputAddresses(value, tronWeb);

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

        const networkCfg = (deployConfig.networks || {})[network];
        if (!networkCfg) {
            throw new Error(`[tron] missing network config for "${network}" in tron/config/deployConfig.js`);
        }

        const cfg = networkCfg.deployPriceFeedChainlink || {};
        if (!cfg.enabled) {
            console.log('[tron] Skip deploy PriceFeedChainlink flow (deployPriceFeedChainlink.enabled=false).');
            return;
        }

        const source = toTronHexAddress(cfg.sourceAddress || '');
        if (!source) {
            throw new Error('[tron] deployPriceFeedChainlink.sourceAddress is required.');
        }

        const maxTimeThreshold = String(cfg.maxTimeThreshold || '86700');
        if (BigInt(maxTimeThreshold) <= 120n) {
            throw new Error('[tron] deployPriceFeedChainlink.maxTimeThreshold must be > 120.');
        }
        const validateAfterDeploy = cfg.validateAfterDeploy === true;

        const deployerAccount = Array.isArray(fromOrAccounts)
            ? fromOrAccounts[0]
            : typeof fromOrAccounts === 'string'
              ? fromOrAccounts
              : networkCfg.deployer;
        const deployerAddress = toTronHexAddress(deployerAccount);

        const outputDir = path.join(__dirname, '..', 'deployments');
        fs.mkdirSync(outputDir, { recursive: true });
        const outputPath = path.join(outputDir, `${network}.pricefeed.chainlink.json`);
        const persistOutput = (obj) => {
            const output = normalizeOutputAddresses(obj);
            fs.writeFileSync(outputPath, `${JSON.stringify(output, null, 2)}\n`, 'utf8');
            return output;
        };

        const priceFeed = await PriceFeedChainlink.new(source, maxTimeThreshold);
        persistOutput({
            network,
            deployer: deployerAddress,
            priceFeedChainlink: priceFeed.address,
            source,
            maxTimeThreshold,
            status: 'deployed_unvalidated',
        });
        console.log(`[tron] priceFeedChainlink=${toTronBase58Address(priceFeed.address)}`);

        let fetchedPrice = '';
        let decimals = 18;
        let validationOk = false;
        let validationWarning = '';
        let unsafePrice = '';
        let updatedAt = 0;
        let ageSec = -1;

        if (validateAfterDeploy) {
            try {
                fetchedPrice = (await priceFeed.fetchPrice()).toString();
                validationOk = true;
            } catch (err) {
                try {
                    const unsafe = await priceFeed.fetchPriceUnsafe();
                    unsafePrice = unsafe[0]?.toString?.() ?? String(unsafe[0]);
                    updatedAt = Number(unsafe[1]?.toString?.() ?? unsafe[1]);
                    const nowSec = Math.floor(Date.now() / 1000);
                    ageSec = Number.isFinite(updatedAt) ? Math.max(0, nowSec - updatedAt) : -1;
                    validationWarning =
                        `[tron] fetchPrice() reverted. source=${toTronBase58Address(source)}, ` +
                        `unsafePrice=${unsafePrice}, updatedAt=${updatedAt}, ageSec=${ageSec}, maxTimeThreshold=${maxTimeThreshold}. ` +
                        'Most likely stale oracle data (ageSec > maxTimeThreshold).';
                } catch (unsafeErr) {
                    const reason = unsafeErr && unsafeErr.message ? unsafeErr.message : String(unsafeErr);
                    validationWarning = `[tron] fetchPrice() reverted and fetchPriceUnsafe() also failed. source=${toTronBase58Address(source)} may not be a valid Chainlink AggregatorV3 on ${network}. details=${reason}`;
                }
            }

            try {
                decimals = Number(await priceFeed.decimals());
            } catch (err) {
                const reason = err && err.message ? err.message : String(err);
                validationWarning = validationWarning
                    ? `${validationWarning}; decimals() failed: ${reason}`
                    : `[tron] decimals() failed: ${reason}`;
            }
        } else {
            validationWarning = '[tron] post-deploy validation skipped (validateAfterDeploy=false).';
        }

        persistOutput({
            network,
            deployer: deployerAddress,
            priceFeedChainlink: priceFeed.address,
            source,
            maxTimeThreshold,
            decimals,
            fetchedPrice,
            validateAfterDeploy,
            validationOk,
            validationWarning,
            unsafePrice,
            updatedAt,
            ageSec,
        });

        console.log('[tron] DeployPriceFeedChainlink completed');
        console.log(`[tron] source=${toTronBase58Address(source)}`);
        console.log(`[tron] decimals=${decimals}`);
        console.log(`[tron] fetchedPrice=${fetchedPrice}`);
        if (!validationOk && validationWarning) {
            console.warn(validationWarning);
        }
        console.log(`[tron] deploy output written: ${outputPath}`);
    });
};

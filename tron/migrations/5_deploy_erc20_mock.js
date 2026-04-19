const fs = require('fs');
const path = require('path');
const deployConfig = require('../config/deployConfig');
const addressUtils = require('./utils/address');

const ERC20Mock = artifacts.require('ERC20Mock');
const toTronHexAddress = (value) => addressUtils.toTronHexAddress(value, tronWeb);
const tryToTronHexAddress = (value) => addressUtils.tryToTronHexAddress(value, tronWeb);
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

        const cfg = networkCfg.deployERC20Mock || {};
        if (!cfg.enabled) {
            console.log('[tron] Skip deploy ERC20Mock flow (deployERC20Mock.enabled=false).');
            return;
        }

        const name = String(cfg.name || 'ERC20 Mock');
        const symbol = String(cfg.symbol || 'MCK');
        const initialMint = String(cfg.initialMint || '0');
        if (BigInt(initialMint) < 0n) {
            throw new Error('[tron] deployERC20Mock.initialMint must be >= 0.');
        }

        const deployerAccount = Array.isArray(fromOrAccounts)
            ? fromOrAccounts[0]
            : typeof fromOrAccounts === 'string'
              ? fromOrAccounts
              : networkCfg.deployer;
        const deployerAddress = toTronHexAddress(deployerAccount);
        const mintTo = tryToTronHexAddress(cfg.mintTo) || deployerAddress;

        const outputDir = path.join(__dirname, '..', 'deployments');
        fs.mkdirSync(outputDir, { recursive: true });
        const outputPath = path.join(outputDir, `${network}.erc20mock.json`);
        const persistOutput = (obj) => {
            const output = normalizeOutputAddresses(obj);
            fs.writeFileSync(outputPath, `${JSON.stringify(output, null, 2)}\n`, 'utf8');
            return output;
        };

        const erc20Mock = await ERC20Mock.new(name, symbol);
        if (BigInt(initialMint) > 0n) {
            await erc20Mock.mint(mintTo, initialMint);
        }

        const decimals = Number(await erc20Mock.decimals());
        const totalSupply = (await erc20Mock.totalSupply()).toString();
        const mintToBalance = (await erc20Mock.balanceOf(mintTo)).toString();

        persistOutput({
            network,
            deployer: deployerAddress,
            erc20Mock: erc20Mock.address,
            name,
            symbol,
            decimals,
            initialMint,
            mintTo,
            totalSupply,
            mintToBalance,
        });

        console.log('[tron] DeployERC20Mock completed');
        console.log(`[tron] erc20Mock=${toTronBase58Address(erc20Mock.address)}`);
        console.log(`[tron] name=${name}`);
        console.log(`[tron] symbol=${symbol}`);
        console.log(`[tron] decimals=${decimals}`);
        console.log(`[tron] totalSupply=${totalSupply}`);
        console.log(`[tron] deploy output written: ${outputPath}`);
    });
};

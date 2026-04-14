require("./tron/scripts/prepareRemappings");
const deployConfig = require("./tron/config/deployConfig");

for (const [name, cfg] of Object.entries(deployConfig.networks || {})) {
  if (!cfg.privateKey) {
    console.warn(`[tronbox] ${name}.privateKey is empty in tron/config/deployConfig.js`);
  }
}

module.exports = {
  contracts_directory: "./tron/contracts",
  contracts_build_directory: "./tron/build/contracts",
  migrations_directory: "./tron/migrations",
  networks: Object.fromEntries(
    Object.entries(deployConfig.networks || {}).map(([name, cfg]) => [
      name,
      {
        privateKey: cfg.privateKey || "",
        userFeePercentage: cfg.userFeePercentage ?? 100,
        feeLimit: cfg.feeLimit ?? 5_000_000_000,
        fullHost: cfg.fullHost,
        network_id: "*",
      },
    ])
  ),
  compilers: {
    solc: {
      version: "0.8.22",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
        evmVersion: "istanbul",
      },
    },
  },
};

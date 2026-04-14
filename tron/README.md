## Satoshi Protocol V2

### TronBox deployment
0. Edit `.env`:
   - TRON_PRIVATE_KEY
   - optional RPC override when default endpoint is unreachable:
     - `TRON_FULL_HOST_NILE` (or global `TRON_FULL_HOST`)
     - `TRON_FULL_HOST_SHASTA`
     - `TRON_FULL_HOST_MAINNET`
1. Edit `tron/config/deployConfig.js`:
   - `networks.<network>.deploySetup` (owner/guardian/feeReceiver/weth/lz and token params)
2. Compile for Tron:
   - `yarn tron:compile`
3. Deploy to Nile testnet:
   - `yarn tron:migrate:nile`

### DeploySetup.s.sol-compatible flow (default)

`tron/migrations/1_deploy_setup_flow.js` follows `script/DeploySetup.s.sol` order:
- deploy beacons, facets, initializer, proxy contracts
- execute facet `diamondCut`
- initialize SatoshiXApp via `Initializer.init`
- apply owner config (`rely`, `setRewardManager`, `setAllocated`, `setClaimStartTime`, `setSPRewardRate`)

Config source:
- `tron/config/deployConfig.js` only (no Tron `.env` dependency)

### DeployInstance flow

`tron/migrations/2_deploy_instance.js` follows `script/DeployInstance.s.sol`:
- `setPriceFeed`
- `deployNewInstance`
- `registerTroveManager`
- `setAllocated`
- `setFarmingParams`
- `setVaultManager`
- `vaultManager.setTroveManager`

Enable and set params in `tron/config/deployConfig.js`:
- `networks.<network>.deployInstance.enabled = true`
- `collateralAddress`
- `priceFeedAddress`
- optional overrides: `MCR`, `minuteDecayFactor`, fee params, `oshiAllocation`, farming params

If setup is already deployed and you only want instance deployment:
- run only migration 2:
  - `yarn tron:migrate:instance:nile`
  - `yarn tron:migrate:instance:shasta`
  - `yarn tron:migrate:instance:mainnet`
- or set `networks.<network>.deploySetup.enabled = false`

### DeployPriceFeedChainlink flow

`tron/migrations/3_deploy_pricefeed_chainlink.js` follows `script/priceFeed/DeployPriceFeedChainlink.s.sol`:
- deploy `PriceFeedChainlink(source, maxTimeThreshold)`
- verify `fetchPrice() > 0`
- write output to `tron/deployments/<network>.pricefeed.chainlink.json`

Enable and set params in `tron/config/deployConfig.js`:
- `networks.<network>.deployPriceFeedChainlink.enabled = true`
- `sourceAddress` (accepts `T...`, `41...`, or `0x...`)
- `maxTimeThreshold` (must be `> 120`)

Run only this migration:
- `yarn tron:migrate:pricefeed:chainlink:nile`
- `yarn tron:migrate:pricefeed:chainlink:shasta`
- `yarn tron:migrate:pricefeed:chainlink:mainnet`

### DeployOracleMock flow

`tron/migrations/4_deploy_oracle_mock.js` deploys `OracleMock(decimals, version)` from `test/mocks/OracleMock.sol`:
- optionally updates `maxTimeThreshold` via `updateMaxTimeThreshold`
- writes output to `tron/deployments/<network>.oraclemock.json`

Enable and set params in `tron/config/deployConfig.js`:
- `networks.<network>.deployOracleMock.enabled = true`
- `decimals`
- `version`
- `maxTimeThreshold` (must be `> 120`)

Run only this migration:
- `yarn tron:migrate:oracle:mock:nile`
- `yarn tron:migrate:oracle:mock:shasta`
- `yarn tron:migrate:oracle:mock:mainnet`

### DeployERC20Mock flow

`tron/migrations/5_deploy_erc20_mock.js` deploys `ERC20Mock(name, symbol)` from `test/mocks/ERC20Mock.sol`:
- optionally mints `initialMint` to `mintTo` (defaults to deployer)
- writes output to `tron/deployments/<network>.erc20mock.json`

Enable and set params in `tron/config/deployConfig.js`:
- `networks.<network>.deployERC20Mock.enabled = true`
- `name`
- `symbol`
- `initialMint`
- `mintTo` (optional)

Run only this migration:
- `yarn tron:migrate:erc20:mock:nile`
- `yarn tron:migrate:erc20:mock:shasta`
- `yarn tron:migrate:erc20:mock:mainnet`

#### Networks

- `nile`: `networks.nile.fullHost`
- `shasta`: `networks.shasta.fullHost`
- `mainnet`: `networks.mainnet.fullHost`

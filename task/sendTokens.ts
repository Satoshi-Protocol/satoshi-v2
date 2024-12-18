import { JsonRpcProvider } from '@ethersproject/providers';
import { ethers, Wallet } from 'ethers'

import { createGetHreByEid, createProviderFactory, getEidForNetworkName } from '@layerzerolabs/devtools-evm-hardhat'
import { Options } from '@layerzerolabs/lz-v2-utilities'
import { arbitrumSepoliaContract, holeskyContract } from '../layerzero.config'
import * as dotenv from 'dotenv'
import { DebtToken__factory } from './types/ethers-contracts/factories/DebtToken__factory';
import { DebtToken } from './types/ethers-contracts/DebtToken';
dotenv.config()
const priv = process.env.DEPLOYMENT_PRIVATE_KEY as string;
const targetAmount = '10';
const sourceContract = arbitrumSepoliaContract;
const destinationContract = holeskyContract;

const sourceRpcUrl = 'https://arb-sepolia.g.alchemy.com/v2/1msadqC7wLHqAL0yEA_NxvASAkAaGRmY';
const destinationRpcUrl = 'https://eth-holesky.g.alchemy.com/v2/oOi2yQOU6RZmvL_9tRTTtdV07ooFpezm';

async function main() {
    const userWallet = new Wallet(process.env.DEPLOYMENT_PRIVATE_KEY as string);
    const eidA = sourceContract.eid;
    const eidB = destinationContract.eid;
    const contractA = sourceContract.address as `0x${string}`;
    const contractB = destinationContract.address as `0x${string}`;
    const recipientB = userWallet.address;
    // const environmentFactory = createGetHreByEid()
    // const providerFactory = createProviderFactory(environmentFactory)
    const provider = new JsonRpcProvider(sourceRpcUrl)
    // await providerFactory(eidA)
    const providerB = new JsonRpcProvider(destinationRpcUrl)

    const wallet = new ethers.Wallet(priv, provider)
    const walletB = new ethers.Wallet(priv, providerB)
    console.log({
        user: userWallet.address,
    })

    const oft = DebtToken__factory.connect(contractA, wallet)
    const oftB = DebtToken__factory.connect(contractB, walletB)
    const beforeBalanceA = await oft.balanceOf(userWallet.address);
    const beforeBalanceB = await oftB.balanceOf(userWallet.address);
    console.log({
        beforeBalanceA: beforeBalanceA.toString(),
        beforeBalanceB: beforeBalanceB.toString(),
    })
    // return;
    const decimals = await oft.decimals()
    const amount = ethers.utils.parseUnits(targetAmount, decimals)
    const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString()
    const recipientAddressBytes32 = ethers.utils.hexZeroPad(recipientB, 32)

    // Estimate the fee
    const [nativeFee] = await oft.quoteSend(
        [eidB, recipientAddressBytes32, amount, amount, options, '0x', '0x'] as any,
        false
    )
    console.log('Estimated native fee:', nativeFee.toString())

    // Fetch the current gas price and nonce
    const gasPrice = await provider.getGasPrice()
    const nonce = await provider.getTransactionCount(wallet.address)

    // Prepare send parameters
    const sendParam = [eidB, recipientAddressBytes32, amount, amount, options, '0x', '0x'] as any;
    const feeParam = [nativeFee, 0] as any;

    // Sending the tokens with increased gas price
    try {
        const tx = await oft.send(sendParam, feeParam, wallet.address, {
            value: nativeFee,
            gasPrice: gasPrice.mul(2),
            nonce,
        })
        console.log('Transaction hash:', tx.hash)
        await tx.wait()
        console.log(
            `Tokens sent successfully to the recipient on the destination chain. View on LayerZero Scan: https://layerzeroscan.com/tx/${tx.hash}`
        )
    } catch (error) {
        console.error('Error sending tokens:', error)
    }

    // Wait for the tokens to be received on the destination chain
    await waitingReceived(recipientB, oftB);
}

async function waitingReceived(user: string, oft: DebtToken) {
    while (true) {
        const balance = await oft.balanceOf(user);
        if (balance.gt(0)) {
            console.log('Tokens received successfully on the destination chain!!!!!!')
            break;
        } else {
            console.log('Waiting for the tokens to be received on the destination chain...')
        }
        await delay(5000);
    }
}

function delay(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms))
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
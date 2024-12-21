import { arbitrumSepoliaContract, holeskyContract, optimismSepoliaContract } from '../layerzero.config';
import { ethers } from 'ethers'
import { task } from 'hardhat/config'

import { createGetHreByEid, createProviderFactory, getEidForNetworkName } from '@layerzerolabs/devtools-evm-hardhat'
import { Options } from '@layerzerolabs/lz-v2-utilities'


const privA = process.env.DEPLOYMENT_PRIVATE_KEY as string;
const privB = process.env.DEPLOYMENT_PRIVATE_KEY_2 as string;
const targetAmount = '10';
// const sourceContract = arbitrumSepoliaContract;
// const destinationContract = optimismSepoliaContract;

const sourceContract = optimismSepoliaContract;
const destinationContract = arbitrumSepoliaContract;

task('lz:oft:send', 'Send tokens cross-chain using LayerZero technology')
.setAction(async (taskArgs, hre) => {
    const eidA = sourceContract.eid;
    const eidB = destinationContract.eid;
    const contractA = sourceContract.address as `0x${string}`;
    const contractB = destinationContract.address as `0x${string}`;
    const environmentFactory = createGetHreByEid();
    const providerFactory = createProviderFactory(environmentFactory);
    const providerA = await providerFactory(eidA);
    const providerB = await providerFactory(eidB);

    const walletA = new ethers.Wallet(privA, providerA);
    const walletB = new ethers.Wallet(privB, providerB);
    console.log({
        userA: walletA.address,
        userB: walletB.address,
    })

    /** */
    const oftContractFactoryA = await hre.ethers.getContractFactory('DebtToken', walletA)
    const oftA = oftContractFactoryA.attach(contractA);
    const oftContractFactoryB = await hre.ethers.getContractFactory('DebtToken', walletB)
    const oftB = oftContractFactoryB.attach(contractB);

    const beforeBalanceOfUserA = await oftA.balanceOf(walletA.address)
    const beforeBalanceOfUserB = await oftB.balanceOf(walletB.address)
    console.log({
        beforeBalanceOfUserA: beforeBalanceOfUserA.toString(),
        beforeBalanceOfUserB: beforeBalanceOfUserB.toString(),
    })
    const decimals = await oftA.decimals()
    const amount = hre.ethers.utils.parseUnits(targetAmount, decimals)
    const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString()
    const recipientAddressBytes32 = hre.ethers.utils.hexZeroPad(walletB.address, 32)

    // Estimate the fee
    const [nativeFee] = await oftA.quoteSend(
        [eidB, recipientAddressBytes32, amount, amount, options, '0x', '0x'],
        false
    )
    console.log('Estimated native fee:', nativeFee.toString())

    // Fetch the current gas price and nonce
    const gasPrice = await providerA.getGasPrice()
    const nonce = await providerA.getTransactionCount(walletA.address)

    // Prepare send parameters
    const sendParam = [eidB, recipientAddressBytes32, amount, amount, options, '0x', '0x']
    const feeParam = [nativeFee, 0]
    console.log({
        nativeFee: hre.ethers.utils.formatEther(nativeFee),
    })

    return;
    // Sending the tokens with increased gas price
    try {
        const tx = await oftA.send(sendParam, feeParam, walletA.address, {
            value: nativeFee,
            gasPrice: gasPrice.mul(2),
            nonce,
        })
        console.log('Transaction hash:', tx.hash)
        await tx.wait()
        console.log(
            `Tokens sent successfully to the recipient on the destination chain. View on LayerZero Scan: https://layerzeroscan.com/tx/${tx.hash}`
        )
        const afterBalanceOfUserA = await oftA.balanceOf(walletA.address)
        const expectedBalanceA = beforeBalanceOfUserA.sub(amount)
        console.log({
            beforeBalanceOfUserA: beforeBalanceOfUserA.toString(),
            afterBalanceOfUserA: afterBalanceOfUserA.toString(),
        })
        if(afterBalanceOfUserA.eq(expectedBalanceA)) {
            console.log('Tokens sent successfully on the source chain');
        } else {
            console.error('Tokens not sent successfully on the source chain !!!!!!');
        }
    } catch (error) {
        console.error('Error sending tokens:', error)
    }

    try {
        const expectedBalanceB = beforeBalanceOfUserB.add(amount)
        while (true) {
            const afterBalanceB = await oftB.balanceOf(walletB.address);
            console.log({
                beforeBalanceB: beforeBalanceOfUserB.toString(),
                afterBalanceB: afterBalanceB.toString(),
            })
            if (afterBalanceB.eq(expectedBalanceB)) {
                console.log('Tokens received successfully on the destination chain!!!!!!')
                break;
            } else {
                console.warn('Waiting for the tokens to be received on the destination chain......')
            }
            await delay(10000);
        }
    } catch (error) {
        console.error('Error receiving tokens:', error)
    }
    console.log('Task completed successfully');
});

function delay(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms))
}

// main()
//     .then(() => process.exit(0))
//     .catch((error) => {
//         console.error(error)
//         process.exit(1)
//     })
import { BigNumber, Contract } from "ethers";
import hre, { ethers, network } from "hardhat";


export async function deployNew(contractName: string, params?: any[]) {
    const C = await ethers.getContractFactory(contractName)
    const contract = await C.deploy(...params!)
    await contract.deployed();
/*     console.log("Contract", contractName, "deployed at", contract.address);
 */    return contract;
}

export async function callAsContract(contract: Contract, impersonateAddr: string, funcNameAsStr: string, params: any[], msgValue?: number) {
    const existingBal = await hre.ethers.provider.getBalance(impersonateAddr)
    if (msgValue === undefined) { msgValue = 0 }
    // Might need to increase this for big transactions
    const txEther = BigNumber.from("10000000000000000000000000")
    const msgValueBn = BigNumber.from(msgValue)

    // Update the balance on the network
    await network.provider.send("hardhat_setBalance", [
        impersonateAddr,
        existingBal.add(txEther).add(msgValueBn).toHexString().replace("0x0", "0x"),
    ])

    // Retrieve the signer for the person to impersonate
    const signer = await ethers.getSigner(impersonateAddr)

    // Impersonate the smart contract to make the corresponding call on their behalf
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [impersonateAddr],
    })

    // Process the transaction on their behalf
    const rec = await contract.connect(signer)[funcNameAsStr](...params, { value: msgValueBn })
    const tx = await rec.wait()

    // The amount of gas consumed by the transaction
    const etherUsedForGas = tx.gasUsed.mul(tx.effectiveGasPrice)
    const extraEther = txEther.sub(etherUsedForGas)

    // Balance post transaction
    const currentBal = await hre.ethers.provider.getBalance(impersonateAddr)

    // Subtract the difference in the amount of ether given
    // vs the amount used in the transaction
    await hre.network.provider.send("hardhat_setBalance", [impersonateAddr, currentBal.sub(extraEther).toHexString().replace("0x0", "0x")])

    // Undo the impersonate so we go back to the default
    await hre.network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: [impersonateAddr],
    })

    return rec
}
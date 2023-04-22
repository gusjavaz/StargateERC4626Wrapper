import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers, network } from "hardhat";
import { BigNumber, Contract, ContractReceipt, ContractTransaction, Wallet } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { StargateERC4626Wrapper, MockToken, Pool, Router, LZEndpointMock, Factory, IERC20, ERC20 } from "../typechain-types";
import { callAsContract, deployNew } from "./utils";

describe("Stargate ERC4626 Wrapper", function () {
    let factory: Factory
    let underlying: MockToken
    let wrapper: StargateERC4626Wrapper
    let router: Router
    let pool: Pool
    let poolId = 1;
    let owner: SignerWithAddress
    let user1: SignerWithAddress
    let user2: SignerWithAddress

    let chainId = 10121
    let amount = 1000000
    let fee = 1000
    let balance = 10000 // 100%
    let idealBalance = 10000 // 100%
    let BP_DENOMINATOR = 100
    let sharedDecimals = 18
    let localDecimals = 18
    let underlyingName = "Token"
    let underlyingSymbol = "TKN"
    let defaultChainPathWeight = 1

    beforeEach(async function () {
        if (hre.network.name == "hardhat") {
            [owner, user1, user2] = await ethers.getSigners();
            const lzEndpoint = (await deployNew("LZEndpointMock", [chainId])) as LZEndpointMock
            router = await deployNew("Router", []) as Router
            factory = await deployNew("Factory", [router.address]) as Factory
            const feeLibrary = await deployNew("StargateFeeLibraryV02", [factory.address])
            const bridge = await deployNew("Bridge", [lzEndpoint.address, router.address])
            await bridge.setBridge(chainId, bridge.address);
            await lzEndpoint.setDestLzEndpoint(bridge.address, lzEndpoint.address)
            underlying = await deployNew("MockToken", [underlyingName, underlyingSymbol, sharedDecimals]) as MockToken
            await callAsContract(factory, router.address, "createPool(uint256,address,uint8,uint8,string,string)", [
                poolId,
                underlying.address,
                sharedDecimals,
                localDecimals,
                await underlying.name(),
                await underlying.symbol(),
            ])
            await router.setBridgeAndFactory(bridge.address, factory.address)
            await router.createChainPath(poolId, chainId, poolId, defaultChainPathWeight)
            await router.setFeeLibrary(poolId, feeLibrary.address)
            await router.setDeltaParam(
                poolId,
                true,
                balance,
                idealBalance,
                true,
                true
            )
            pool = await ethers.getContractAt("Pool", await factory.getPool(1), owner)
            await router.setFees(poolId, 1000);
        }
        if (hre.network.name == "arbitrum-goerli") {
            const factoryContract = "0x1dAC955a58f292b8d95c6EBc79d14D3E618971b2"
            const routerContract = "0xb850873f4c993Ac2405A1AdD71F6ca5D4d4d6b4f"
            const tokenContract = "0x6aAd876244E7A1Ad44Ec4824Ce813729E5B6C291" //USDC
            const poolId = 1;
            factory = await ethers.getContractAt("Factory", factoryContract, owner);
            router = await ethers.getContractAt("IStargateRouter", routerContract, owner) as Router;
            underlying = await ethers.getContractAt("IERC20", tokenContract, owner) as MockToken;
        }

        wrapper = await deployNew("StargateERC4626Wrapper", [factory.address, router.address, underlying.address, poolId]) as StargateERC4626Wrapper;
        await underlying.connect(owner).mint(user1.address, amount)
        await underlying.connect(owner).mint(user2.address, amount)
        await underlying.connect(owner).approve(wrapper.address, amount)
    });

    it("Should deposit", async function () {
        const expectedShareBalance = (await wrapper.balanceOf(user1.address)).add(amount).sub(fee * BP_DENOMINATOR)
        const expectedTokenBalance = (await underlying.balanceOf(user1.address)).sub(amount)
        await underlying.connect(user1).approve(wrapper.address, amount)
        await wrapper.connect(user1).deposit(amount, user1.address)
        expect(await wrapper.balanceOf(user1.address)).to.be.equal(expectedShareBalance)
        expect(await underlying.balanceOf(user1.address)).to.be.equal(expectedTokenBalance)
    });

    it("Should withdraw", async function () {
        await underlying.connect(user1).approve(wrapper.address, amount)
        await wrapper.deposit(amount, user1.address)
        const expectedShareBalance = (await wrapper.balanceOf(user1.address)).sub(amount).add(fee * BP_DENOMINATOR)
        const expectedTokenBalance = (await underlying.balanceOf(user1.address)).add(amount).sub(fee * BP_DENOMINATOR)
        await pool.connect(user1).approve(wrapper.address, amount);
        await wrapper.withdraw(amount - fee * BP_DENOMINATOR, user1.address, user1.address)
        expect(await wrapper.balanceOf(user1.address)).to.be.equal(expectedShareBalance)
        expect(await underlying.balanceOf(user1.address)).to.be.equal(expectedTokenBalance)
    });

    it("Should get totalAssets", async function () {
        await underlying.connect(user1).approve(wrapper.address, amount)
        await wrapper.deposit(amount, user1.address)
        const expectedTotalAssets = amount
        expect(await wrapper.totalAssets()).to.be.equal(expectedTotalAssets)
    });

    it("Should preview withdraw", async function () {
        await underlying.connect(user1).approve(wrapper.address, amount)
        await wrapper.deposit(amount, user1.address)
        const expectedWithdrawAmount = amount;
        expect(await wrapper.previewWithdraw(amount)).to.be.equal(expectedWithdrawAmount)
    });

    it("Should preview redeem", async function () {
        await underlying.connect(user1).approve(wrapper.address, amount)
        await wrapper.deposit(amount, user1.address)
        const expectedRedeemAmount = amount;
        expect(await wrapper.previewRedeem(amount)).to.be.equal(expectedRedeemAmount)
    });

    it("Should get max withdraw", async function () {
        await underlying.connect(user1).approve(wrapper.address, amount)
        await wrapper.deposit(amount, user1.address)
        const expectedMaxWithdraw = amount - fee * BP_DENOMINATOR;
        expect(await wrapper.maxWithdraw(user1.address)).to.be.equal(expectedMaxWithdraw)
    });

    it("Should get max deposit", async function () {
        await underlying.connect(user1).approve(wrapper.address, amount)
        await wrapper.deposit(amount, user1.address)
        const expectedMaxWithdraw = BigNumber.from("115792089237316195423570985008687907853269984665640564039457584007913129639935") // type(uint256).max
        expect(await wrapper.maxDeposit(user1.address)).to.be.equal(expectedMaxWithdraw)
    });


});





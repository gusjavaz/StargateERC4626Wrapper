import hre, { ethers } from "hardhat";

async function main() {
  const otherValue = 100;

  const [owner, otherAccount] = await ethers.getSigners();

  const factoryContract = "0x1dAC955a58f292b8d95c6EBc79d14D3E618971b2"
  const routerContract = "0xb850873f4c993Ac2405A1AdD71F6ca5D4d4d6b4f"
  const tokenContract = "0x6aAd876244E7A1Ad44Ec4824Ce813729E5B6C291" //USDC
  const poolId = 1;

  const factory = await ethers.getContractAt("Factory", factoryContract, owner);
  const router = await ethers.getContractAt("IStargateRouter", routerContract, owner);
  const underlying = await ethers.getContractAt("IERC20", tokenContract, owner);
  const wrapperFactory = await ethers.getContractFactory("StargateERC4626Wrapper");
  const wrapper = await wrapperFactory.deploy(factory.address, router.address, underlying.address, poolId);

  console.log(
    `StargateERC4626Wrapper deployed at`, wrapper.address
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

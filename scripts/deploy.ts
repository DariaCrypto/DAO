import { ethers, run } from "hardhat";

async function main() {
  const [signer] = await ethers.getSigners();

  const minimumQuorum: number = 51;
  const debatingPeriodDuration: number = 259200; // 3 days
  const _minimumVotes: number = 1000;

  const DAO = await ethers.getContractFactory("DAO");
  const Token = await ethers.getContractFactory("Token");

  const token = await Token.deploy();
  await token.deployed();

  const DAO_deploy = await DAO.deploy(
    token.address,
    minimumQuorum,
    debatingPeriodDuration,
    _minimumVotes
  );
  await DAO_deploy.deployed();



}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

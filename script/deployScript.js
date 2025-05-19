// Requires ethers.js setup
async function main() {
  const [deployer] = await ethers.getSigners();
  const VirtualSniper = await ethers.getContractFactory("VirtualsSniper");
  const sniper = await VirtualSniper.deploy(
    "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    "0x4200000000000000000000000000000000000006"
  );
  console.log("Deployed to:", await sniper.getAddress());
}
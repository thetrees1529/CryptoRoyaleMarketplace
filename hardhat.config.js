require("@nomiclabs/hardhat-ethers");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    devnet: {
      url: "https://api.s0.ps.hmny.io",
      accounts: ["423a6c9415c1c09490f25a1e62f9fb53e6ad2f7fdddf4a468c205738be8a9906"]
    }
  },

  solidity: "0.8.15"
};

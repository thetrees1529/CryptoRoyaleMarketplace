const fs = require("fs")
const path = require("path")


const ROYAddress = hre.ethers.constants.AddressZero

async function main() {
    const BuyItNow = await hre.ethers.getContractFactory("BuyItNow")
    const buyItNow = await (await BuyItNow.deploy(ROYAddress)).deployed()
    fs.writeFileSync(path.join(__dirname, "deployedAt.json"), JSON.stringify(buyItNow.address))
    console.log(`Deployed at ${buyItNow.address}`)
}

main()
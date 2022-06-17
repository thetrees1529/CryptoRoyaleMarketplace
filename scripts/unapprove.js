const collection = hre.ethers.constants.AddressZero
const contractAddress = require("./deployedAt")
async function main() {
    const buyItNow = await hre.ethers.getContractAt("BuyItNow", contractAddress)
    await (await buyItNow.unapproveCollection(collection)).wait()
    console.log(`Successfully unapproved collection ${collection}`)
}
main()
const Lottery = artifacts.require("Lottery");

contract('Lottery', function ([accA, accB, accC]) {
    beforeEach(async () => {
        contract  = await Lottery.deployed();
    });

    it('verify owner', async () => {
        const ownerAddress = await contract.OWNER()
        console.log('accA address', accA);
    })
});
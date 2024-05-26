const HelloWorld = artifacts.require("HelloWorld");

contract('HelloWorld', function(accounts) {
  beforeEach(async () => {
    contract = await HelloWorld.new();
  });
  it("need show greeting", async () => {
    const res = await contract.greeting();

    assert(res === "Ola, tudo bem?");
  });

});

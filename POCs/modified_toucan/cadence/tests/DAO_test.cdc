import Test

access(all) let account = Test.createAccount()

access(all) fun testContract() {
    let err = Test.deployContract(
        name: "ToucanDAO",
        path: "../contracts/ToucanDAO.cdc",
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}
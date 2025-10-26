import FungibleToken from "../utility/FungibleToken.cdc"
import Toucans from "../Toucans.cdc"

access(all) fun main(user: Address, projects: {String: Address}): {String: UFix64} {
  let answer: {String: UFix64} = {}
  for projectId in projects.keys {
    let owner: Address = projects[projectId]!
    let projectCollection = getAccount(owner).capabilities.get<&Toucans.Collection>(Toucans.CollectionPublicPath).borrow()
                ?? panic("User does not have a Toucans Collection")
    let project = projectCollection.borrowProjectPublic(projectId: projectId)!

    if let vault = getAccount(user).capabilities.get<&{FungibleToken.Balance}>(project.projectTokenInfo.publicPath).borrow() {
      let contractAddressToString: String = project.projectTokenInfo.contractAddress.toString()
      let constructedIdentifier: String = "A.".concat(contractAddressToString.slice(from: 2, upTo: contractAddressToString.length)).concat(".").concat(project.projectTokenInfo.contractName).concat(".Vault")
      if vault.getType().identifier == constructedIdentifier {
        answer[projectId] = vault.balance
      }
    } 
  }

  let flowVault = getAccount(user).capabilities.get<&{FungibleToken.Balance}>(/public/flowTokenBalance).borrow()!
  answer["Flow"] = flowVault.balance

  let usdcVault = getAccount(user).capabilities.get<&{FungibleToken.Balance}>(/public/USDCVaultBalance).borrow()
  answer["USDC"] = usdcVault?.balance ?? 0.0

  let stFlowVault = getAccount(user).capabilities.get<&{FungibleToken.Balance}>(/public/stFlowTokenBalance).borrow()
  answer["stFlow"] = stFlowVault?.balance ?? 0.0
  
  return answer
}
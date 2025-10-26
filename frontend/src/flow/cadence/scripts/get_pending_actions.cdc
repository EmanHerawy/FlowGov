import Toucans from "../Toucans.cdc"
import ToucansActions from "../ToucansActions.cdc"

access(all) fun main(user: Address, projectOwners: [Address], projectIds: [String]): {String: [Action]} {
  pre {
    projectOwners.length == projectIds.length: "Must input same number of inputs."
  }
  let answer: {String: [Action]} = {}
  var i = 0
  while i < projectOwners.length {
    let projectId = projectIds[i]
    let projectCollection = getAccount(projectOwners[i]).capabilities.borrow<&Toucans.Collection>(Toucans.CollectionPublicPath)
                ?? panic("User does not have a Toucans Collection")
    let manager = projectCollection.borrowProjectPublic(projectId: projectId)!.borrowManagerPublic()
    let actions: [Action] = []
    for actionId in manager.getIDs() {
      let action = manager.borrowAction(actionUUID: actionId)
      let actionDetails = action.action
      
      // Since actionDetails is AnyStruct, we need to extract intent and title based on type
      var intent = ""
      var title = ""
      let typeId = actionDetails.getType().identifier
      
      // Try to cast to known action types to get intent and title
      if typeId == Toucans.getActionTypeId("WithdrawToken") {
        let a = actionDetails as! ToucansActions.WithdrawToken
        intent = a.getIntent()
        title = a.getTitle()
      } else if typeId == Toucans.getActionTypeId("BatchWithdrawToken") {
        let a = actionDetails as! ToucansActions.BatchWithdrawToken
        intent = a.getIntent()
        title = a.getTitle()
      } else if typeId == Toucans.getActionTypeId("WithdrawNFTs") {
        let a = actionDetails as! ToucansActions.WithdrawNFTs
        intent = a.getIntent()
        title = a.getTitle()
      } else if typeId == Toucans.getActionTypeId("MintTokens") {
        let a = actionDetails as! ToucansActions.MintTokens
        intent = a.getIntent()
        title = a.getTitle()
      } else if typeId == Toucans.getActionTypeId("BatchMintTokens") {
        let a = actionDetails as! ToucansActions.BatchMintTokens
        intent = a.getIntent()
        title = a.getTitle()
      } else if typeId == Toucans.getActionTypeId("BurnTokens") {
        let a = actionDetails as! ToucansActions.BurnTokens
        intent = a.getIntent()
        title = a.getTitle()
      } else if typeId == Toucans.getActionTypeId("MintTokensToTreasury") {
        let a = actionDetails as! ToucansActions.MintTokensToTreasury
        intent = a.getIntent()
        title = a.getTitle()
      } else if typeId == Toucans.getActionTypeId("AddOneSigner") {
        let a = actionDetails as! ToucansActions.AddOneSigner
        intent = a.getIntent()
        title = a.getTitle()
      } else if typeId == Toucans.getActionTypeId("RemoveOneSigner") {
        let a = actionDetails as! ToucansActions.RemoveOneSigner
        intent = a.getIntent()
        title = a.getTitle()
      } else if typeId == Toucans.getActionTypeId("UpdateThreshold") {
        let a = actionDetails as! ToucansActions.UpdateTreasuryThreshold
        intent = a.getIntent()
        title = a.getTitle()
      } else if typeId == Toucans.getActionTypeId("LockTokens") {
        let a = actionDetails as! ToucansActions.LockTokens
        intent = a.getIntent()
        title = a.getTitle()
      } else {
        // Unknown action type
        intent = "Unknown Action"
        title = "Unknown Action Type"
      }
      
      actions.append(Action(actionId, intent, title, action.threshold, action.getVotes(), action.getSigners()))
    }
    
    answer[projectId] = actions
    i = i + 1
  }

  return answer
}

access(all) struct Action {
  access(all) let id: UInt64
  access(all) let intent: String
  access(all) let title: String
  access(all) let threshold: UInt64
  access(all) let votes: {Address: Bool}
  access(all) let signers: [Address]

  init(_ id: UInt64, _ i: String, _ t: String, _ th: UInt64, _ s: {Address: Bool}, _ si: [Address]) {
    self.id = id
    self.intent = i
    self.title = t
    self.threshold = th
    self.votes = s
    self.signers = si
  }
}

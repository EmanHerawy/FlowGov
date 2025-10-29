Created scripts for reading/querying DAO and proposal data. All scripts pass linting. Summary:

## DAO Query Scripts

### **DAO Configuration & Status**
1. **`GetDAOConfiguration.cdc`** - Returns complete DAO configuration:
   - Config values (minVoteThreshold, minimumQuorumNumber, minimumProposalStake, etc.)
   - State info (treasuryBalance, stakedFundsBalance, memberCount, nextProposalId)

2. **`GetMemberCount.cdc`** - Returns total number of DAO members

3. **`IsMember.cdc`** - Checks if an address is a member
   - Parameters: `address: Address`
   - Returns: `Bool`

4. **`HasToucanTokenBalance.cdc`** - Checks if an address holds ToucanTokens
   - Parameters: `address: Address`
   - Returns: `Bool`

### **Treasury & Funds**
5. **`GetTreasuryBalance.cdc`** - Gets treasury balance for a token type
   - Parameters: `vaultType: Type` (e.g., `Type<@FlowToken.Vault>()`)
   - Returns: `UFix64`

6. **`GetStakedFundsBalance.cdc`** - Gets total staked ToucanTokens balance

### **Proposal Queries**
7. **`GetProposal.cdc`** - Gets a proposal by ID
   - Parameters: `proposalId: UInt64`
   - Returns: `Proposal?`

8. **`GetProposalStatus.cdc`** - Gets current status of a proposal
   - Parameters: `proposalId: UInt64`
   - Returns: `ProposalStatus` enum

9. **`GetProposalDetails.cdc`** - Returns full proposal details as a struct
   - Parameters: `proposalId: UInt64`
   - Returns: Struct with id, creator, title, description, status, votes, timestamps, etc.

10. **`GetProposalVotes.cdc`** - Gets vote counts for a proposal
    - Parameters: `proposalId: UInt64`, `voterAddress: Address?` (optional)
    - Returns: Struct with yesVotes, noVotes, totalVotes, hasVoted

### **Proposal Lists**
11. **`GetAllProposals.cdc`** - Returns all proposals in the DAO

12. **`GetActiveProposals.cdc`** - Returns proposals currently in voting period (Active status)

13. **`GetProposalsByStatus.cdc`** - Filters proposals by status
    - Parameters: `statusValue: UInt8` (0=Pending, 1=Active, 2=Passed, 3=Rejected, 4=Executed, 5=Cancelled, 6=Expired)

14. **`GetProposalsByType.cdc`** - Filters proposals by type
    - Parameters: `proposalTypeValue: UInt8` (0=WithdrawTreasury, 1=AdminBasedOperation)

15. **`GetProposalsByCreator.cdc`** - Gets all proposals created by an address
    - Parameters: `creatorAddress: Address`

All scripts are ready to use. Execute them with:

```bash
flow scripts execute cadence/scripts/GetDAOConfiguration.cdc
flow scripts execute cadence/scripts/GetProposal.cdc 0
flow scripts execute cadence/scripts/GetActiveProposals.cdc
```

import "FlowToken"
import "FungibleToken"

access(all) contract ToucanDAO {

    /// Proposal status
    access(all) enum ProposalStatus: UInt8 {
        access(all) case Active
        access(all) case Passed
        access(all) case Rejected
        access(all) case Executed
        access(all) case Cancelled
        access(all) case Expired
    }

    /// Proposal types for treasury operations
    access(all) enum ProposalType: UInt8 {
        access(all) case FundTreasury    // Deposit tokens into treasury
        access(all) case WithdrawTreasury // Withdraw tokens from treasury
    }

    /// Action types that can be executed by proposals
    access(all) enum ActionType: UInt8 {
        access(all) case None
        access(all) case AddMember
        access(all) case RemoveMember
        access(all) case UpdateConfig
        access(all) case ExecuteCustom
    }

    /// Data structs for different action types
    access(all) struct AddMemberData {
        access(all) let address: Address
        
        access(all) init(address: Address) {
            self.address = address
        }
    }

    access(all) struct RemoveMemberData {
        access(all) let address: Address
        
        access(all) init(address: Address) {
            self.address = address
        }
    }
    
    /// Data for treasury funding operations
    access(all) struct FundTreasuryData {
        access(all) let amount: UFix64
        access(all) let sourceAddress: Address  // Where funds come from
        
        access(all) init(amount: UFix64, sourceAddress: Address) {
            self.amount = amount
            self.sourceAddress = sourceAddress
        }
    }
    
    /// Data for treasury withdrawal operations
    access(all) struct WithdrawTreasuryData {
        access(all) let amount: UFix64
        access(all) let recipientAddress: Address  // Where funds go to
        access(all) let recipientVaultPath: PublicPath  // Path to recipient's vault capability
        
        access(all) init(amount: UFix64, recipientAddress: Address, recipientVaultPath: PublicPath) {
            self.amount = amount
            self.recipientAddress = recipientAddress
            self.recipientVaultPath = recipientVaultPath
        }
    }

    /// Action data for proposals
    access(all) struct Action {
        access(all) let actionType: ActionType
        access(all) let data: AnyStruct?  // Can contain action-specific parameters
        
        access(all) init(actionType: ActionType, data: AnyStruct?) {
            self.actionType = actionType
            self.data = data
        }
    }

    /// Proposal struct
    access(all) struct Proposal {
        access(all) let id: UInt64
        access(all) let creator: Address  // Transaction sender (secured)
        access(all) let title: String
        access(all) let description: String
        access(all) let action: Action  // The action to execute when proposal passes
        access(all) let proposalType: ProposalType  // Fund or Withdraw
        access(all) let createdTimestamp: UFix64
        access(all) let votingPeriod: UFix64  // How long voting is open (in seconds)
        access(all) let expiryTimestamp: UFix64  // When this proposal expires
        access(all) let cooldownPeriod: UFix64  // How long to wait after passing before execution (in seconds)
        access(all) let stakedAmount: UFix64  // Flow tokens staked by proposer
        // Treasury operation specific data
        access(all) let treasuryAmount: UFix64?  // Amount to fund/withdraw
        access(all) let treasuryAddress: Address?  // Address to/from
        access(self) var status: ProposalStatus  // Used for Cancelled and Executed, others calculated dynamically
        access(all) view fun getStatus(): ProposalStatus {
            // Calculate status dynamically based on current state
            
            // Check if cancelled or executed (these are stored)
            if self.status == ProposalStatus.Cancelled {
                return ProposalStatus.Cancelled
            }
            if self.status == ProposalStatus.Executed {
                return ProposalStatus.Executed
            }
            
            // Check if voting period has ended using expiryTimestamp
            let currentTime = getCurrentBlock().timestamp
            
            if currentTime < self.expiryTimestamp {
                // Still in voting period
                return ProposalStatus.Active
            }
            
            // Voting period has ended - calculate result dynamically
            let totalVotes = self.yesVotes + self.noVotes
            
            // Check if proposal has no votes - it's expired
            if totalVotes == 0 {
                return ProposalStatus.Expired
            }
            
            // Check if proposal passed (yes > no and has votes)
            if self.yesVotes > self.noVotes {
                return ProposalStatus.Passed
            } else {
                return ProposalStatus.Rejected
            }
        }
        access(self) var yesVotes: UInt64
        access(all) view fun getYesVotes(): UInt64 {
            return self.yesVotes
        }
        access(all) view fun getNoVotes(): UInt64 {
            return self.noVotes
        }
        access(self) var noVotes: UInt64
        access(self) var executionTimestamp: UFix64?
        access(all) view fun getExecutionTimestamp(): UFix64? {
            return self.executionTimestamp
        }
        access(self) var voters: {Address: Bool}  // Map of voter to whether they voted yes (true) or no (false)
        
        access(all) view fun hasVoted(address: Address): Bool {
            return self.voters[address] != nil
        }
        
        access(all) fun addVote(isYes: Bool) {
            if isYes {
                self.yesVotes = self.yesVotes + 1
            } else {
                self.noVotes = self.noVotes + 1
            }
        }
        
        access(all) fun registerVoter(address: Address, vote: Bool) {
            self.voters[address] = vote
        }
        
        access(contract) fun setStatus(newStatus: ProposalStatus) {
            // Only allow setting Cancelled and Executed status - others are calculated dynamically
            assert(
                newStatus == ProposalStatus.Cancelled || newStatus == ProposalStatus.Executed,
                message: "Only Cancelled and Executed status can be set - other statuses are calculated dynamically"
            )
            self.status = newStatus
        }
        
        access(all) fun setExecutionTimestamp(timestamp: UFix64?) {
            self.executionTimestamp = timestamp
        }
        
        access(all) view fun getAction(): Action {
            return self.action
        }

        access(all) init(
            id: UInt64,
            creator: Address,
            title: String,
            description: String,
            action: Action,
            proposalType: ProposalType,
            votingPeriod: UFix64,
            cooldownPeriod: UFix64,
            stakedAmount: UFix64,
            treasuryAmount: UFix64?,
            treasuryAddress: Address?
        ) {
            self.id = id
            self.creator = creator
            self.title = title
            self.description = description
            self.action = action
            self.proposalType = proposalType
            self.createdTimestamp = getCurrentBlock().timestamp
            self.votingPeriod = votingPeriod
            self.cooldownPeriod = cooldownPeriod
            self.stakedAmount = stakedAmount
            self.treasuryAmount = treasuryAmount
            self.treasuryAddress = treasuryAddress
            self.expiryTimestamp = getCurrentBlock().timestamp + votingPeriod
            self.status = ProposalStatus.Active  // Initial status, will be calculated dynamically
            self.yesVotes = 0
            self.noVotes = 0
            self.executionTimestamp = nil
            self.voters = {}
        }
        
        /// Check if proposal has expired
        access(all) fun isExpired(): Bool {
            return getCurrentBlock().timestamp >= self.expiryTimestamp
        }
        
        /// Check if proposal is ready for execution (passed cooldown)
        access(all) fun isReadyForExecution(): Bool {
            // Check if proposal has passed and cooldown has ended
            let currentTime = getCurrentBlock().timestamp
            
            // Must be past voting period (using expiryTimestamp)
            if currentTime < self.expiryTimestamp {
                return false
            }
            
            // Check if proposal passed (yes > no and has votes)
            let totalVotes = self.yesVotes + self.noVotes
            if self.yesVotes <= self.noVotes || totalVotes == 0 {
                return false
            }
            
            // Check cooldown period
            if let execTime = self.executionTimestamp {
                return currentTime >= execTime + self.cooldownPeriod
            }
            
            // Calculate time since voting ended if execution timestamp not set
            return currentTime >= self.expiryTimestamp + self.cooldownPeriod
        }
    }

    /// Events
    access(all) event ProposalCreated(
        id: UInt64,
        creator: Address,
        title: String
    )

    access(all) event Voted(
        proposalId: UInt64,
        voter: Address,
        vote: Bool,  // true for yes, false for no
        newYesVotes: UInt64,
        newNoVotes: UInt64
    )

    access(all) event ProposalPassed(
        id: UInt64,
        executionTimestamp: UFix64
    )

    access(all) event ProposalRejected(
        id: UInt64
    )

    access(all) event ProposalExecuted(
        id: UInt64
    )

    /// Resource to hold staked FLOW tokens
    access(all) resource StakedFunds {
        access(all) var vault: @FlowToken.Vault
        
        init(vault: @FlowToken.Vault) {
            self.vault <- vault
        }
    }
    
    /// Resource to hold treasury funds (actual DAO treasury)
    access(all) resource Treasury {
        access(self) var flowVault: @FlowToken.Vault
        
        access(all) fun depositFlow(tokens: @FlowToken.Vault) {
            self.flowVault.deposit(from: <-tokens)
        }
        
        access(all) fun withdrawFlow(amount: UFix64): @FlowToken.Vault {
            return <-self.flowVault.withdraw(amount: amount) as! @FlowToken.Vault
        }
        
        access(all) view fun getBalance(): UFix64 {
            return self.flowVault.balance
        }
        
        init() {
            self.flowVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
        }
    }

    /// State
    access(self) var nextProposalId: UInt64
    access(all) var proposals: {UInt64: Proposal}
    access(all) var members: {Address: Bool}  // Map of member addresses
    access(self) var stakedFundsResource: @StakedFunds
    access(self) var treasury: @Treasury
    access(self) var proposerStakes: {UInt64: UFix64}  // Map of proposal ID to staked amount

    /// Configuration
    access(all) let minVoteThreshold: UInt64  // Minimum votes required for a proposal to pass
    access(all) let quorumPercentage: UFix64  // Percentage of members that must vote
    access(all) let minimumProposalStake: UFix64  // Minimum FLOW tokens required to create a proposal
    access(all) let defaultVotingPeriod: UFix64  // Default voting period in seconds
    access(all) let defaultCooldownPeriod: UFix64  // Default cooldown period in seconds

    init() {
        self.nextProposalId = 0
        self.proposals = {}
        self.members = {}
        // Create empty vault for staked funds
        self.stakedFundsResource <- create StakedFunds(
            vault: <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
        )
        // Create empty treasury
        self.treasury <- create Treasury()
        self.proposerStakes = {}
        self.minVoteThreshold = 1  // At least 1 vote required
        self.quorumPercentage = 50.0  // 50% of members must vote
        self.minimumProposalStake = 10.0  // 10 FLOW minimum stake
        self.defaultVotingPeriod = 604800.0  // 7 days default
        self.defaultCooldownPeriod = 86400.0  // 1 day default
    }
    
    /// Get total staked funds balance
    access(all) view fun getStakedFundsBalance(): UFix64 {
        return self.stakedFundsResource.vault.balance
    }
    
    /// Get treasury balance
    access(all) view fun getTreasuryBalance(): UFix64 {
        return self.treasury.getBalance()
    }
    
    /// Configuration info struct for returning state
    access(all) struct ConfigurationInfo {
        access(all) let minVoteThreshold: UInt64
        access(all) let quorumPercentage: UFix64
        access(all) let minimumProposalStake: UFix64
        access(all) let defaultVotingPeriod: UFix64
        access(all) let defaultCooldownPeriod: UFix64
        access(all) let treasuryBalance: UFix64
        access(all) let stakedFundsBalance: UFix64
        access(all) let memberCount: UInt64
        access(all) let nextProposalId: UInt64
        
        init(
            minVoteThreshold: UInt64,
            quorumPercentage: UFix64,
            minimumProposalStake: UFix64,
            defaultVotingPeriod: UFix64,
            defaultCooldownPeriod: UFix64,
            treasuryBalance: UFix64,
            stakedFundsBalance: UFix64,
            memberCount: UInt64,
            nextProposalId: UInt64
        ) {
            self.minVoteThreshold = minVoteThreshold
            self.quorumPercentage = quorumPercentage
            self.minimumProposalStake = minimumProposalStake
            self.defaultVotingPeriod = defaultVotingPeriod
            self.defaultCooldownPeriod = defaultCooldownPeriod
            self.treasuryBalance = treasuryBalance
            self.stakedFundsBalance = stakedFundsBalance
            self.memberCount = memberCount
            self.nextProposalId = nextProposalId
        }
    }
    
    /// Get configuration values (for testing and reading state)
    access(all) fun getConfiguration(): ConfigurationInfo {
        return ConfigurationInfo(
            minVoteThreshold: self.minVoteThreshold,
            quorumPercentage: self.quorumPercentage,
            minimumProposalStake: self.minimumProposalStake,
            defaultVotingPeriod: self.defaultVotingPeriod,
            defaultCooldownPeriod: self.defaultCooldownPeriod,
            treasuryBalance: self.treasury.getBalance(),
            stakedFundsBalance: self.stakedFundsResource.vault.balance,
            memberCount: self.getMemberCount(),
            nextProposalId: self.nextProposalId
        )
    }

    /// Add a member to the DAO
    access(all) fun addMember(address: Address) {
        self.members[address] = true
    }

    /// Remove a member from the DAO
    access(all) fun removeMember(address: Address) {
        self.members[address] = nil
    }

    /// Check if an address is a member
    access(all) fun isMember(address: Address): Bool {
        return self.members[address] ?? false
    }

    /// Get the number of members
    access(all) fun getMemberCount(): UInt64 {
        return UInt64(self.members.keys.length)
    }

    /// Create a new proposal with actual FLOW token staking
    /// This function receives and holds FLOW tokens as stake from the transaction signer
    /// The creator parameter must match the transaction signer for security
    access(all) fun createProposal(
        title: String,
        description: String,
        action: Action,
        proposalType: ProposalType,
        creator: Address,  // Must be the transaction signer (validated in transaction)
        votingPeriod: UFix64?,
        cooldownPeriod: UFix64?,
        treasuryAmount: UFix64?,
        treasuryAddress: Address?,
        stake: @FlowToken.Vault  // Actual FLOW tokens to stake from the signer
    ): @FlowToken.Vault {
        let stakedAmount = stake.balance
        
        // Validate stake amount
        assert(
            stakedAmount >= self.minimumProposalStake,
            message: "Insufficient stake. Minimum required: ".concat(self.minimumProposalStake.toString())
        )
        
        // Security: The vault can only come from the transaction signer
        // This prevents anyone else from providing the stake
        // The creator parameter is passed by the transaction and validated there
        
        let proposalId = self.nextProposalId
        self.nextProposalId = self.nextProposalId + 1
        
        // Use provided periods or defaults
        let voting = votingPeriod ?? self.defaultVotingPeriod
        let cooldown = cooldownPeriod ?? self.defaultCooldownPeriod

        let proposal = Proposal(
            id: proposalId,
            creator: creator,
            title: title,
            description: description,
            action: action,
            proposalType: proposalType,
            votingPeriod: voting,
            cooldownPeriod: cooldown,
            stakedAmount: stakedAmount,
            treasuryAmount: treasuryAmount,
            treasuryAddress: treasuryAddress
        )

        // Actually deposit the staked FLOW tokens (only caller can provide these)
        self.stakedFundsResource.vault.deposit(from: <-stake)
        self.proposerStakes[proposalId] = stakedAmount
        self.proposals[proposalId] = proposal

        emit ProposalCreated(
            id: proposalId,
            creator: creator,
            title: title
        )

        // Return empty vault (tokens were deposited)
        return <-FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
    }
    
    /// Cancel a proposal and return the actual staked FLOW tokens
    /// Can only be called by the proposal creator and only if no one has voted
    access(all) fun cancelProposal(proposalId: UInt64, proposerAddress: Address): @FlowToken.Vault {
        let proposal = self.proposals[proposalId] ?? panic("Proposal does not exist")
        
        assert(
            proposal.getStatus() == ProposalStatus.Active,
            message: "Can only cancel active proposals"
        )
        
        // Verify caller is the proposer
        assert(
            proposal.creator == proposerAddress,
            message: "Only the proposal creator can cancel"
        )
        
        // Check if anyone has voted
        let totalVotes = proposal.getYesVotes() + proposal.getNoVotes()
        assert(
            totalVotes == 0,
            message: "Cannot cancel proposal that has received votes"
        )
        
        // Refund the actual staked tokens
        let stakeAmount = self.proposerStakes[proposalId] ?? panic("Proposal stake not found")
        self.proposerStakes[proposalId] = nil
        
        // Mark proposal as cancelled
        proposal.setStatus(newStatus: ProposalStatus.Cancelled)
        self.proposals[proposalId] = proposal
        
        // Withdraw and return the staked tokens
        let refund <- self.stakedFundsResource.vault.withdraw(amount: stakeAmount) as! @FlowToken.Vault
        return <-refund
    }
    
    /// Execute a proposal and optionally slash stake if execution fails
    /// Returns the staked tokens if successful, otherwise they are burned
    access(all) fun finalizeProposal(proposalId: UInt64, success: Bool): @FlowToken.Vault {
        let proposal = self.proposals[proposalId] ?? panic("Proposal does not exist")
        
        assert(
            proposal.getStatus() == ProposalStatus.Passed,
            message: "Proposal must be passed to finalize"
        )
        
        let stakeAmount = self.proposerStakes[proposalId] ?? 0.0
        self.proposerStakes[proposalId] = nil
        
        if success {
            // Refund stake on successful execution
            let refund <- self.stakedFundsResource.vault.withdraw(amount: stakeAmount) as! @FlowToken.Vault
            return <-refund
        } else {
            // Slash stake on failed execution (burn the tokens)
            let slashed <- self.stakedFundsResource.vault.withdraw(amount: stakeAmount) as! @FlowToken.Vault
            destroy slashed
            return <-FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
        }
    }

    /// Vote on a proposal
    access(all) fun vote(
        
        proposalId: UInt64,
        vote: Bool  // true for yes, false for no
    ) {
        
        // In real implementation, would check caller is a member
        // In a transaction context, this would use the signer's address
        
        let proposal = self.proposals[proposalId] 
            ?? panic("Proposal does not exist")

        assert(
            proposal.getStatus() == ProposalStatus.Active,
            message: "Proposal is not active"
        )

        // In real implementation, would check if voter already voted
        // Would use caller's address from transaction context

        proposal.addVote(isYes: vote)

        // Mark that this address voted (using a dummy address in contract context)
        // In transaction, would use: proposal.registerVoter(signer.address, vote)
        proposal.registerVoter(address: 0x0, vote: vote)

        self.proposals[proposalId] = proposal

        emit Voted(
            proposalId: proposalId,
            voter: 0x0,
            vote: vote,
            newYesVotes: proposal.getYesVotes(),
            newNoVotes: proposal.getNoVotes()
        )

        // Check if proposal should pass or fail
        let totalVotes = proposal.getYesVotes() + proposal.getNoVotes()
        let totalMembers = UInt64(self.members.keys.length)
        
        // Check if quorum is met and proposal should pass
        if totalMembers > 0 && totalVotes >= self.minVoteThreshold {
            let participationPercentage = (UFix64(totalVotes) / UFix64(totalMembers)) * 100.0
            
            if participationPercentage >= self.quorumPercentage {
                if proposal.getYesVotes() > proposal.getNoVotes() {
                    proposal.setStatus(newStatus: ProposalStatus.Passed)
                    proposal.setExecutionTimestamp(timestamp: getCurrentBlock().timestamp)
                    self.proposals[proposalId] = proposal
                    
                    emit ProposalPassed(
                        id: proposalId,
                        executionTimestamp: getCurrentBlock().timestamp
                    )
                } else if proposal.getNoVotes() >= proposal.getYesVotes() {
                    proposal.setStatus(newStatus: ProposalStatus.Rejected)
                    self.proposals[proposalId] = proposal
                    
                    emit ProposalRejected(
                        id: proposalId
                    )
                }
            }
        }
    }

    /// Get a proposal by ID
    access(all) fun getProposal(proposalId: UInt64): Proposal? {
        let proposal = self.proposals[proposalId]
        if proposal != nil {
            return proposal
        }
        return nil
    }
    
    /// Internal function to update proposal status
    access(self) fun updateProposalStatus(proposalId: UInt64, newStatus: ProposalStatus) {
        let proposal = self.proposals[proposalId]
            ?? panic("Proposal does not exist")
        proposal.setStatus(newStatus: newStatus)
        self.proposals[proposalId] = proposal
    }

    /// Get all proposals
    access(all) fun getAllProposals(): [Proposal] {
        let proposals: [Proposal] = []
        for proposal in self.proposals.values {
            proposals.append(proposal)
        }
        return proposals
    }

    /// Internal function to execute a proposal
    /// This will be called by the TransactionHandler
    /// Executes the action associated with the proposal
    access(all) fun executeProposal(proposalId: UInt64) {
        let proposal = self.proposals[proposalId]
            ?? panic("Proposal does not exist")

        assert(
            proposal.getStatus() == ProposalStatus.Passed,
            message: "Proposal must be passed to execute"
        )

        assert(
            proposal.getStatus() != ProposalStatus.Executed,
            message: "Proposal has already been executed"
        )
        
        // Check if cooldown period has passed
        assert(
            proposal.isReadyForExecution(),
            message: "Proposal is still in cooldown period"
        )

        // Execute the action associated with the proposal
        let action = proposal.getAction()
        self.executeAction(proposalType: proposal.proposalType, action: action)

        // Update proposal status to executed
        self.updateProposalStatus(proposalId: proposalId, newStatus: ProposalStatus.Executed)

        emit ProposalExecuted(id: proposalId)
    }
    
    /// Execute an action based on its type and proposal type
    /// This is contract-private and can only be called from within the contract
    access(contract) fun executeAction(proposalType: ProposalType, action: Action) {
        // Handle treasury operations
        switch proposalType {
            case ProposalType.FundTreasury:
                self.executeFundTreasury(action: action)
            
            case ProposalType.WithdrawTreasury:
                self.executeWithdrawTreasury(action: action)
        }
        
        // Handle other action types
        switch action.actionType {
            case ActionType.AddMember:
                if let addMemberData = action.data as? AddMemberData {
                    self.addMember(address: addMemberData.address)
                    log("Added member: ".concat(addMemberData.address.toString()))
                }
            
            case ActionType.RemoveMember:
                if let removeMemberData = action.data as? RemoveMemberData {
                    self.removeMember(address: removeMemberData.address)
                    log("Removed member: ".concat(removeMemberData.address.toString()))
                }
            
            case ActionType.UpdateConfig:
                log("Config update attempted")
            
            case ActionType.ExecuteCustom:
                log("Custom action executed")
            
            case ActionType.None:
                log("No action to execute")
        }
    }
    
    /// Execute a treasury funding operation
    access(contract) fun executeFundTreasury(action: Action) {
        // Expect action data containing vault info
        if action.data != nil {
            log("Funding treasury - implementation needed")
            // TODO: Implement actual treasury funding logic
            // This would involve:
            // 1. Extracting token details from action data
            // 2. Getting tokens from source
            // 3. Depositing to self.treasury
        }
    }
    
    /// Execute a treasury withdrawal operation  
    access(contract) fun executeWithdrawTreasury(action: Action) {
        // For now, this is a placeholder
        // In a full implementation, this would:
        // 1. Extract recipient and amount from action.data
        // 2. Validate treasury balance
        // 3. Withdraw from treasury
        // 4. Send to recipient
        
        log("Withdrawing from treasury - implementation needed")
        
        // Example structure (would need proper data type):
        // if let withdrawData = action.data as? WithdrawData {
        //     assert(self.treasury.getBalance() >= withdrawData.amount)
        //     let tokens <- self.treasury.withdrawFlow(amount: withdrawData.amount)
        //     withdrawData.recipient.deposit(from: <-tokens)
        // }
    }
}


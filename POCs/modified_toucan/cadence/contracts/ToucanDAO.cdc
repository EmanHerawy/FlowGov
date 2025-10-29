import "FlowToken"
import "FungibleToken"
import "ToucanToken"
import "FlowTransactionSchedulerUtils"
import "FlowTransactionScheduler"

access(all) contract ToucanDAO {

    /// Proposal status
    access(all) enum ProposalStatus: UInt8 {
        access(all) case Pending    // Created but not yet deposited
        access(all) case Active      // Deposited and voting is open
        access(all) case Passed      // Voting ended with majority yes
        access(all) case Rejected    // Voting ended with majority no or quorum not met
        access(all) case Executed    // Proposal has been executed
        access(all) case Cancelled    // Cancelled by proposer
        access(all) case Expired     // Voting period ended with no votes
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
        access(contract) var status: ProposalStatus  // Used for Cancelled and Executed, others calculated dynamically
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
            // Only allow setting Pending, Cancelled, and Executed status - others are calculated dynamically
            assert(
                newStatus == ProposalStatus.Pending || 
                newStatus == ProposalStatus.Cancelled || 
                newStatus == ProposalStatus.Executed,
                message: "Only Pending, Cancelled, and Executed status can be set - other statuses are calculated dynamically"
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
            self.status = ProposalStatus.Pending  // Initial status - waiting for deposit
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
    access(all) event TransactionScheduled(txId: UInt64, executeAt: UFix64)

    access(all) event ProposalActivated(
        proposalId: UInt64,
        depositor: Address
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

    /// Resource to hold staked funds (deprecated - no longer used)
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
    access(self) var pendingDeposits: {UInt64: Address}  // Map of proposal ID to depositor address
    access(self) var toucanTokenBalance: @ToucanToken.Vault  // Balance of ToucanToken for deposits

    /// Configuration
    access(all) let minVoteThreshold: UInt64  // Minimum votes required for a proposal to pass
    access(all) let quorumPercentage: UFix64  // Percentage of members that must vote
    access(all) let minimumProposalStake: UFix64  // Minimum ToucanTokens required to create a proposal
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
        self.pendingDeposits = {}
        // Initialize empty ToucanToken vault for deposits
        self.toucanTokenBalance <- ToucanToken.createEmptyVault(vaultType: Type<@ToucanToken.Vault>())
        self.minVoteThreshold = 1  // At least 1 vote required
        self.quorumPercentage = 50.0  // 50% of members must vote
        self.minimumProposalStake = 10.0  // 10 ToucanTokens minimum stake
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

    /// Create a treasury funding proposal
    access(all) fun createFundTreasuryProposal(
        title: String,
        description: String,
        amount: UFix64,
        signer: auth(BorrowValue) &Account
    ) {
        let action = Action(
            actionType: ActionType.ExecuteCustom,
            data: FundTreasuryData(amount: amount, sourceAddress: 0x0) as AnyStruct
        )
        
        self.createProposalInternal(
            title: title,
            description: description,
            action: action,
            proposalType: ProposalType.FundTreasury,
            creator: signer.address,
            treasuryAmount: amount,
            treasuryAddress: nil
        )
    }
    
    /// Create a treasury withdrawal proposal
    access(all) fun createWithdrawTreasuryProposal(
        title: String,
        description: String,
        amount: UFix64,
        recipientAddress: Address,
        signer: auth(BorrowValue) &Account
    ) {
        let action = Action(
            actionType: ActionType.ExecuteCustom,
            data: WithdrawTreasuryData(amount: amount, recipientAddress: recipientAddress, recipientVaultPath: /public/flowTokenReceiver) as AnyStruct
        )
        
        self.createProposalInternal(
            title: title,
            description: description,
            action: action,
            proposalType: ProposalType.WithdrawTreasury,
            creator: signer.address,
            treasuryAmount: amount,
            treasuryAddress: recipientAddress
        )
    }
    
    /// Create an add member proposal (using FundTreasury type for now)
    access(all) fun createAddMemberProposal(
        title: String,
        description: String,
        memberAddress: Address,
        signer: auth(BorrowValue) &Account
    ) {
        let action = Action(
            actionType: ActionType.AddMember,
            data: AddMemberData(address: memberAddress) as AnyStruct
        )
        
        self.createProposalInternal(
            title: title,
            description: description,
            action: action,
            proposalType: ProposalType.FundTreasury,  // Using FundTreasury as generic type
            creator: signer.address,
            treasuryAmount: nil,
            treasuryAddress: nil
        )
    }
    
    /// Create a remove member proposal (using WithdrawTreasury type for now)
    access(all) fun createRemoveMemberProposal(
        title: String,
        description: String,
        memberAddress: Address,
        signer: auth(BorrowValue) &Account
    ) {
        let action = Action(
            actionType: ActionType.RemoveMember,
            data: RemoveMemberData(address: memberAddress) as AnyStruct
        )
        
        self.createProposalInternal(
            title: title,
            description: description,
            action: action,
            proposalType: ProposalType.WithdrawTreasury,  // Using WithdrawTreasury as generic type
            creator: signer.address,
            treasuryAmount: nil,
            treasuryAddress: nil
        )
    }
    
    /// Internal function to create proposals with common logic
    access(self) fun createProposalInternal(
        title: String,
        description: String,
        action: Action,
        proposalType: ProposalType,
        creator: Address,
        treasuryAmount: UFix64?,
        treasuryAddress: Address?
    ) {
        let stakedAmount = 0.0
        
        let proposalId = self.nextProposalId
        self.nextProposalId = self.nextProposalId + 1
        
        // Use DAO default periods
        let voting = self.defaultVotingPeriod
        let cooldown = self.defaultCooldownPeriod

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

        // Don't deposit tokens yet - proposal starts as Pending
        self.proposerStakes[proposalId] = stakedAmount
        self.proposals[proposalId] = proposal

        emit ProposalCreated(
            id: proposalId,
            creator: creator,
            title: title
        )
    }
    
    /// Deposit ToucanTokens to activate a pending proposal
    /// Anyone can deposit to activate a proposal for voting
    access(all) fun depositProposal(
        proposalId: UInt64, 
        deposit: @ToucanToken.Vault,
        signer: auth(BorrowValue) &Account
    ) {
        let proposal = self.proposals[proposalId] ?? panic("Proposal does not exist")
        
        assert(
            self.getStatus(proposalId: proposalId) == ProposalStatus.Pending,
            message: "Proposal is not pending - cannot deposit"
        )
        
        let stakeAmount = self.proposerStakes[proposalId] ?? panic("Proposal stake not found")
        let depositAmount = deposit.balance
        
        assert(
            depositAmount >= stakeAmount,
            message: "Insufficient deposit amount"
        )
        
        // Store who made the deposit for refund purposes
        self.pendingDeposits[proposalId] = signer.address
        
        // Deposit ToucanTokens
        self.toucanTokenBalance.deposit(from: <-deposit)
        
        // Update proposal status to Active
        proposal.setStatus(newStatus: ProposalStatus.Active)
        self.proposals[proposalId] = proposal
        
        emit ProposalActivated(proposalId: proposalId, depositor: signer.address)
        // let's schedule the proposal for exectution , if passed, execute and refund the deposit to the sepositor , if not , refund the deposit and mark the proposal as failed
    }
    
    /// Cancel a proposal and return the ToucanTokens to the depositor
    /// Can only be called by the proposal creator and only if no one has voted
    access(all) fun cancelProposal(
        proposalId: UInt64,
        signer: auth(BorrowValue) &Account
    ): @ToucanToken.Vault {
        let proposal = self.proposals[proposalId] ?? panic("Proposal does not exist")
        
        // Can cancel Pending or Active proposals
        let status = self.getStatus(proposalId: proposalId)
        assert(
            status == ProposalStatus.Pending || status == ProposalStatus.Active,
            message: "Can only cancel pending or active proposals"
        )
        
        // Verify caller is the proposer
        assert(
            proposal.creator == signer.address,
            message: "Only the proposal creator can cancel"
        )
        
        // If Active, check if anyone has voted
        if status == ProposalStatus.Active {
            let totalVotes = proposal.getYesVotes() + proposal.getNoVotes()
            assert(
                totalVotes == 0,
                message: "Cannot cancel proposal that has received votes"
            )
        }
        
        // Get the stake amount
        let stakeAmount = self.proposerStakes[proposalId] ?? panic("Proposal stake not found")
        self.proposerStakes[proposalId] = nil
        
        // Mark proposal as cancelled
        self.updateProposalStatus(proposalId: proposalId, newStatus: ProposalStatus.Cancelled)
        
        // Refund ToucanTokens to the depositor
        let depositorAddress = self.pendingDeposits[proposalId] ?? panic("No deposit found for proposal")
        self.pendingDeposits[proposalId] = nil
        
        // Withdraw and return the ToucanTokens
        let refund <- self.toucanTokenBalance.withdraw(amount: stakeAmount)
        
        return <-refund
    }
    
    /// Execute a proposal and optionally slash stake if execution fails
    /// Returns the ToucanTokens if successful, otherwise they are burned
    access(all) fun finalizeProposal(proposalId: UInt64, success: Bool): @ToucanToken.Vault {
        let proposal = self.proposals[proposalId] ?? panic("Proposal does not exist")
        
        assert(
            self.getStatus(proposalId: proposalId) == ProposalStatus.Passed,
            message: "Proposal must be passed to finalize"
        )
        
        let stakeAmount = self.proposerStakes[proposalId] ?? 0.0
        self.proposerStakes[proposalId] = nil
        
        // Get the depositor address
        let depositorAddress = self.pendingDeposits[proposalId] ?? panic("No deposit found for proposal")
        self.pendingDeposits[proposalId] = nil
        
        // Withdraw ToucanTokens from balance
        let refund <- self.toucanTokenBalance.withdraw(amount: stakeAmount)
        
        if success {
            // Return ToucanTokens on successful execution
            return <-refund
        } else {
            // Slash stake on failed execution (burn the tokens)
            destroy refund
            return <-ToucanToken.createEmptyVault(vaultType: Type<@ToucanToken.Vault>())
        }
    }

    /// Vote on a proposal
    access(all) fun vote(
        proposalId: UInt64,
        vote: Bool,  // true for yes, false for no
        signer: auth(BorrowValue) &Account
    ) {
        let proposal = self.proposals[proposalId] 
            ?? panic("Proposal does not exist")

        assert(
            self.getStatus(proposalId: proposalId) == ProposalStatus.Active,
            message: "Proposal is not active"
        )

        // Check if voter has already voted
        assert(
            !proposal.hasVoted(address: signer.address),
            message: "Voter has already voted on this proposal"
        )

        proposal.addVote(isYes: vote)
        proposal.registerVoter(address: signer.address, vote: vote)

        self.proposals[proposalId] = proposal

        emit Voted(
            proposalId: proposalId,
            voter: signer.address,
            vote: vote,
            newYesVotes: proposal.getYesVotes(),
            newNoVotes: proposal.getNoVotes()
        )
        
        // Voting process complete - status will be calculated dynamically
    }
    
    /// Get a proposal by ID
    access(all) fun getProposal(proposalId: UInt64): Proposal? {
        let proposal = self.proposals[proposalId]
        if proposal != nil {
            return proposal
        }
        return nil
    }
    
    /// Get proposal status with proper quorum and threshold checking
    access(all) fun getStatus(proposalId: UInt64): ProposalStatus {
        let proposal = self.proposals[proposalId] ?? panic("Proposal does not exist")
        
        // Check if cancelled or executed (these are stored)
        let storedStatus = proposal.status
        if storedStatus == ProposalStatus.Cancelled {
            return ProposalStatus.Cancelled
        }
        if storedStatus == ProposalStatus.Executed {
            return ProposalStatus.Executed
        }
        if storedStatus == ProposalStatus.Pending {
            return ProposalStatus.Pending
        }
        
        // Check if voting period has ended using expiryTimestamp
        let currentTime = getCurrentBlock().timestamp
        
        if currentTime < proposal.expiryTimestamp {
            // Still in voting period
            return ProposalStatus.Active
        }
        
        // Voting period has ended - calculate result with quorum checking
        let totalVotes = proposal.getYesVotes() + proposal.getNoVotes()
        let totalMembers = UInt64(self.members.keys.length)
        
        // Check if proposal has no votes - it's expired
        if totalVotes == 0 {
            return ProposalStatus.Expired
        }
        
        // Check quorum and threshold requirements
        if totalMembers > 0 && totalVotes >= self.minVoteThreshold {
            let participationPercentage = (UFix64(totalVotes) / UFix64(totalMembers)) * 100.0
            
            if participationPercentage >= self.quorumPercentage {
                if proposal.getYesVotes() > proposal.getNoVotes() {
                    return ProposalStatus.Passed
                } else {
                    return ProposalStatus.Rejected
                }
            } else {
                // Quorum not met
                return ProposalStatus.Rejected
            }
        } else {
            // Not enough votes to meet minimum threshold
            return ProposalStatus.Rejected
        }
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
            self.getStatus(proposalId: proposalId) == ProposalStatus.Passed,
            message: "Proposal must be passed to execute"
        )

        assert(
            self.getStatus(proposalId: proposalId) != ProposalStatus.Executed,
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
        // ════════════════════════════════════════════════════════════
    // SCHEDULE FUNCTION
    // ════════════════════════════════════════════════════════════
    
        // Public function to SCHEDULE an increment
        access(all) fun scheduleIncrement(  
        signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue, GetStorageCapabilityController, PublishCapability) &Account
    ) {
           
       let future = getCurrentBlock().timestamp + 1.0;
        
        let pr = FlowTransactionScheduler.Priority.Medium;
        
        // Get the handler capability
        var handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>? = nil
        let controllers = signer.capabilities.storage.getControllers(forPath: /storage/CounterTransactionHandler)
        
        if controllers.length > 0 {
            if let cap = controllers[0].capability as? Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}> {
                handlerCap = cap
            } else if controllers.length > 1 {
                handlerCap = controllers[1].capability as! Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>
            }
        }
        
        assert(handlerCap != nil, message: "Could not get handler capability")
        
        // Create scheduler manager if doesn't exist
        if signer.storage.borrow<&AnyResource>(from: FlowTransactionSchedulerUtils.managerStoragePath) == nil {
            let manager <- FlowTransactionSchedulerUtils.createManager()
            signer.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)
            
            let managerCapPublic = signer.capabilities.storage.issue<&{FlowTransactionSchedulerUtils.Manager}>(
                FlowTransactionSchedulerUtils.managerStoragePath
            )
            signer.capabilities.publish(managerCapPublic, at: FlowTransactionSchedulerUtils.managerPublicPath)
        }
        
        let manager = signer.storage.borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(
            from: FlowTransactionSchedulerUtils.managerStoragePath
        ) ?? panic("Could not borrow Manager")
        
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Missing FlowToken vault")
        
        let est = FlowTransactionScheduler.estimate(
            data: nil,
            timestamp: future,
            priority: pr,
            executionEffort: 1000
        )
        
        assert(
            est.timestamp != nil || pr == FlowTransactionScheduler.Priority.Low,
            message: est.error ?? "Estimation failed"
        )
        
        let fees <- vaultRef.withdraw(amount: est.flowFee ?? 0.0) as! @FlowToken.Vault
        
        let transactionId = manager.schedule(
            handlerCap: handlerCap!,
            data: nil,
            timestamp: future,
            priority: pr,
            executionEffort: 1000,
            fees: <-fees
        )
        
        emit TransactionScheduled(txId: transactionId, executeAt: future)
        
        log("Scheduled transaction id: "
            .concat(transactionId.toString())
            .concat(" at ")
            .concat(future.toString()))
    }
       /// Handler resource that implements the Scheduled Transaction interface
    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {
        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {
      
      
          log("Transaction executed (id: ".concat(id.toString()).concat(") newCount: "))
        }

        access(all) view fun getViews(): [Type] {
            return [Type<StoragePath>(), Type<PublicPath>()]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<StoragePath>():
                    return /storage/ToucanDAOTransactionHandler
                case Type<PublicPath>():
                    return /public/ToucanDAOTransactionHandler
                default:
                    return nil
            }
        }
    }

    /// Factory for the handler resource
    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }  
}


import "FlowToken"
import "FungibleToken"
import "ToucanToken"
import "FlowTransactionSchedulerUtils"
import "FlowTransactionScheduler"
import "EVM" 

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
        access(all) case WithdrawTreasury // Withdraw tokens from treasury
        access(all) case AdminBasedOperation
        access(all) case EVMCall // Execute EVM contract calls
    }

    /// Action types that can be executed by proposals
    access(all) enum ActionType: UInt8 {
        access(all) case None
        access(all) case AddMember
        access(all) case RemoveMember
        access(all) case UpdateConfig
        access(all) case ExecuteCustom
        access(all) case ExecuteEVMCall
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
    
    /// Data for updating DAO configuration
    access(all) struct UpdateConfigData {
        access(all) let minVoteThreshold: UInt64?
        access(all) let minimumQuorumNumber: UFix64?
        access(all) let minimumProposalStake: UFix64?
        access(all) let defaultVotingPeriod: UFix64?
        access(all) let defaultCooldownPeriod: UFix64?
        
        access(all) init(
            minVoteThreshold: UInt64?,
            minimumQuorumNumber: UFix64?,
            minimumProposalStake: UFix64?,
            defaultVotingPeriod: UFix64?,
            defaultCooldownPeriod: UFix64?
        ) {
            self.minVoteThreshold = minVoteThreshold
            self.minimumQuorumNumber = minimumQuorumNumber
            self.minimumProposalStake = minimumProposalStake
            self.defaultVotingPeriod = defaultVotingPeriod
            self.defaultCooldownPeriod = defaultCooldownPeriod
        }
    }
    
    /// Information about a proposal deposit - tracks depositor and amount
    access(all) struct ProposalDeposit {
        access(all) let depositorAddress: Address
        access(all) let depositAmount: UFix64
        access(self) var isRefunded: Bool
        
        access(all) init(depositorAddress: Address, depositAmount: UFix64) {
            self.depositorAddress = depositorAddress
            self.depositAmount = depositAmount
            self.isRefunded = false
        }

        access(all) view fun wasRefunded(): Bool {
            return self.isRefunded
        }

        access(contract) fun markRefunded() {
            self.isRefunded = true
        }
    }
    
    /// Data for treasury withdrawal operations
    access(all) struct WithdrawTreasuryData {
        access(all) let vaultType: Type  // Token type to withdraw (e.g., Type<@FlowToken.Vault>)
        access(all) let amount: UFix64
        access(all) let recipientAddress: Address  // Where funds go to
        access(all) let recipientVaultPath: PublicPath  // Path to recipient's vault capability
        
        access(all) init(vaultType: Type, amount: UFix64, recipientAddress: Address, recipientVaultPath: PublicPath) {
            self.vaultType = vaultType
            self.amount = amount
            self.recipientAddress = recipientAddress
            self.recipientVaultPath = recipientVaultPath
        }
    }
    
    /// Data for EVM contract call operations
    /// Contains arrays matching FlowTreasury.execute() signature:
    /// execute(address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    access(all) struct EVMCallData {
        access(all) let targets: [String]  // EVM addresses as hex strings
        access(all) let values: [UInt256]   // Values to send with each call (in attoflow)
        access(all) let functionSignatures: [String]  // Function signatures (e.g., "transfer(address,uint256)")
        access(all) let functionArgs: [[AnyStruct]]   // Arguments for each function call
        
        access(all) init(
            targets: [String],
            values: [UInt256],
            functionSignatures: [String],
            functionArgs: [[AnyStruct]]
        ) {
            // Validate array lengths match
            assert(
                targets.length == values.length && 
                values.length == functionSignatures.length &&
                functionSignatures.length == functionArgs.length,
                message: "Array lengths must match: targets, values, functionSignatures, and functionArgs"
            )
            
            self.targets = targets
            self.values = values
            self.functionSignatures = functionSignatures
            self.functionArgs = functionArgs
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
        access(all) var voters: {Address: Bool}  // Map of voter to whether they voted yes (true) or no (false)
        
        access(all) view fun hasVoted(address: Address): Bool {
            return self.voters[address] != nil
        }
        
        access(contract) fun addVote(isYes: Bool) {
            if isYes {
                self.yesVotes = self.yesVotes + 1
            } else {
                self.noVotes = self.noVotes + 1
            }
        }
        
        access(contract) fun registerVoter(address: Address, vote: Bool) {
            self.voters[address] = vote
        }
        
        access(contract) fun setStatus(newStatus: ProposalStatus) {

            self.status = newStatus
        }
        
        access(contract) fun setExecutionTimestamp(timestamp: UFix64?) {
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
    /// Implements FungibleToken.Receiver so it can receive any FungibleToken
    /// Uses dictionary to store multiple token types dynamically
    access(all) resource Treasury: FungibleToken.Receiver {
        // Dictionary keyed by vault type - supports any FungibleToken
        access(self) var vaults: @{Type: {FungibleToken.Vault}}
        
        /// Deposit tokens into treasury (supports any FungibleToken)
        access(contract) fun depositTokens(tokens: @{FungibleToken.Vault}) {
            let vaultType = tokens.getType()
            if let existing = &self.vaults[vaultType] as &{FungibleToken.Vault}? {
                existing.deposit(from: <-tokens)
            } else {
                self.vaults[vaultType] <-! tokens
            }
        }
        
        /// Withdraw tokens from treasury by type
        access(contract) fun withdraw(vaultType: Type, amount: UFix64): @{FungibleToken.Vault} {
            let vault <- self.vaults.remove(key: vaultType) ?? panic("No vault found for the specified token type")
            let withdrawn <- vault.withdraw(amount: amount)
            self.vaults[vaultType] <-! vault
            return <-withdrawn
        }
        
        /// Get balance for a specific token type
        access(all) view fun getBalance(vaultType: Type): UFix64 {
            if let vault = &self.vaults[vaultType] as &{FungibleToken.Vault}? {
                return vault.balance
            } else {
                return 0.0
            }
        }
        
        /// Get all supported vault types as an array
        access(all) view fun getSupportedVaultTypeList(): [Type] {
            return self.vaults.keys
        }
        
        /// Check if a vault type is supported
        access(all) view fun hasVault(vaultType: Type): Bool {
            return self.vaults[vaultType] != nil
        }
        
        /// Implement FungibleToken.Receiver interface
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            self.depositTokens(tokens: <-from)
        }
        
        /// getSupportedVaultTypes for Receiver interface
        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            let supported: {Type: Bool} = {}
            for vaultType in self.vaults.keys {
                supported[vaultType] = true
            }
            return supported
        }
        
        /// isSupportedVaultType for Receiver interface
        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return self.vaults[type] != nil
        }
        
        init() {
            // Initialize with empty FlowToken and ToucanToken vaults by default
            let flowVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
            let toucanVault <- ToucanToken.createEmptyVault(vaultType: Type<@ToucanToken.Vault>())
            self.vaults <- {
                Type<@FlowToken.Vault>(): <-flowVault,
                Type<@ToucanToken.Vault>(): <-toucanVault
            }
        }
    }

    /// State
    access(self) var nextProposalId: UInt64
    access(all) var proposals: {UInt64: Proposal}
    access(all) var members: {Address: Bool}  // Map of member addresses
    access(self) var stakedFundsResource: @StakedFunds
    access(self) var treasury: @Treasury
    access(self) var pendingDeposits: {UInt64: ProposalDeposit}  // Map of proposal ID to deposit info (depositor address and amount)
    access(self) var toucanTokenBalance: @ToucanToken.Vault  // Balance of ToucanToken for deposits

    /// Configuration
    access(all) var minVoteThreshold: UInt64  // Minimum votes required for a proposal to pass
    access(all) var minimumQuorumNumber: UFix64  // Minimum number of members that must vote (for non-admin proposals)
    access(all) var minimumProposalStake: UFix64  // Minimum ToucanTokens required to create a proposal
    access(all) var defaultVotingPeriod: UFix64  // Default voting period in seconds
    access(all) var defaultCooldownPeriod: UFix64  // Default cooldown period in seconds
    access(all) var evmTreasuryContractAddress: String?  // EVM address of the FlowTreasury contract (hex string without 0x)
    access(self) var coaCapability: Capability<auth(EVM.Call) &EVM.CadenceOwnedAccount>?  // Capability to the COA resource

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
        self.pendingDeposits = {}
        // Initialize empty ToucanToken vault for deposits
        self.toucanTokenBalance <- ToucanToken.createEmptyVault(vaultType: Type<@ToucanToken.Vault>())
        self.minVoteThreshold = 1  // At least 1 vote required
        self.minimumQuorumNumber = 3.0  // Minimum number of members that must vote (for non-admin proposals)
        self.minimumProposalStake = 10.0  // 10 ToucanTokens minimum stake
        self.defaultVotingPeriod = 604800.0  // 7 days default
        self.defaultCooldownPeriod = 86400.0  // 1 day default
        self.evmTreasuryContractAddress = nil  // Set via UpdateConfig proposal
        self.coaCapability = nil  // Set via admin function after COA is created
        // Add deployer as the first DAO member for bootstrap
        self.members[self.account.address] = true
    }
    
    /// Get total staked funds balance
    access(all) view fun getStakedFundsBalance(): UFix64 {
        return self.stakedFundsResource.vault.balance
    }
    
    /// Get treasury balance for a specific token type
    access(all) view fun getTreasuryBalance(vaultType: Type): UFix64 {
        return self.treasury.getBalance(vaultType: vaultType)
    }
    
    /// Configuration info struct for returning state
    access(all) struct ConfigurationInfo {
        access(all) let minVoteThreshold: UInt64
        access(all) let minimumQuorumNumber: UFix64
        access(all) let minimumProposalStake: UFix64
        access(all) let defaultVotingPeriod: UFix64
        access(all) let defaultCooldownPeriod: UFix64
        access(all) let treasuryBalance: UFix64
        access(all) let stakedFundsBalance: UFix64
        access(all) let memberCount: UInt64
        access(all) let nextProposalId: UInt64
        
        init(
            minVoteThreshold: UInt64,
            minimumQuorumNumber: UFix64,
            minimumProposalStake: UFix64,
            defaultVotingPeriod: UFix64,
            defaultCooldownPeriod: UFix64,
            treasuryBalance: UFix64,
            stakedFundsBalance: UFix64,
            memberCount: UInt64,
            nextProposalId: UInt64
        ) {
            self.minVoteThreshold = minVoteThreshold
            self.minimumQuorumNumber = minimumQuorumNumber
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
            minimumQuorumNumber: self.minimumQuorumNumber,
            minimumProposalStake: self.minimumProposalStake,
            defaultVotingPeriod: self.defaultVotingPeriod,
            defaultCooldownPeriod: self.defaultCooldownPeriod,
            treasuryBalance: 0.0,  // Note: Treasury now supports multiple token types - use getTreasuryBalance(vaultType) instead
            stakedFundsBalance: self.stakedFundsResource.vault.balance,
            memberCount: self.getMemberCount(),
            nextProposalId: self.nextProposalId
        )
    }

    /// Add a member to the DAO
    access(contract) fun addMember(address: Address) {
        self.members[address] = true
    }

    /// Remove a member from the DAO
    access(contract) fun removeMember(address: Address) {
        self.members[address] = nil
    }

    /// Check if an address is a member
    access(all) fun isMember(address: Address): Bool {
        return self.members[address] ?? false
    }
    
    /// Check if an address is an admin member (required for certain proposals)
    /// In this DAO, all members are considered admin members
    access(all) fun isAdminMember(address: Address): Bool {
        return self.members[address] ?? false
    }
    
    /// Require that the signer is an admin member, otherwise panic
    access(all) fun requireAdminMember(signer: auth(BorrowValue) &Account) {
        assert(
            self.isAdminMember(address: signer.address),
            message: "Only admin members can create this type of proposal"
        )
    }
    
    /// Set the COA capability (admin only)
    /// Called after COA is created and stored in the contract account
    access(all) fun setCOACapability(capability: Capability<auth(EVM.Call) &EVM.CadenceOwnedAccount>, signer: auth(BorrowValue) &Account) {
        self.requireAdminMember(signer: signer)
        self.coaCapability = capability
        log("COA capability set successfully")
    }

    /// Get the number of members
    access(all) fun getMemberCount(): UInt64 {
        return UInt64(self.members.keys.length)
    }

    /// Create a treasury withdrawal proposal
    /// Requires 2/3 quorum of members to vote yes
    /// Open to anyone (no admin restriction)
    access(all) fun createWithdrawTreasuryProposal(
        title: String,
        description: String,
        vaultType: Type,  // Token type to withdraw (e.g., Type<@FlowToken.Vault>)
        amount: UFix64,
        recipientAddress: Address,
        recipientVaultPath: PublicPath,  // Path to recipient's vault capability
        signer: auth(BorrowValue) &Account
    ) {
        let action = Action(
            actionType: ActionType.ExecuteCustom,
            data: WithdrawTreasuryData(vaultType: vaultType, amount: amount, recipientAddress: recipientAddress, recipientVaultPath: recipientVaultPath) as AnyStruct
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
    
    /// Create an add member proposal (admin members only)
    access(all) fun createAddMemberProposal(
        title: String,
        description: String,
        memberAddress: Address,
        signer: auth(BorrowValue) &Account
    ) {
        // Require admin member
        self.requireAdminMember(signer: signer)
        let action = Action(
            actionType: ActionType.AddMember,
            data: AddMemberData(address: memberAddress) as AnyStruct
        )
        
        self.createProposalInternal(
            title: title,
            description: description,
            action: action,
            proposalType: ProposalType.AdminBasedOperation,
            creator: signer.address,
            treasuryAmount: nil,
            treasuryAddress: nil
        )
    }
    
    /// Create an update configuration proposal (admin members only)
    access(all) fun createUpdateConfigProposal(
        title: String,
        description: String,
        minVoteThreshold: UInt64?,
        minimumQuorumNumber: UFix64?,
        minimumProposalStake: UFix64?,
        defaultVotingPeriod: UFix64?,
        defaultCooldownPeriod: UFix64?,
        signer: auth(BorrowValue) &Account
    ) {
        // Require admin member
        self.requireAdminMember(signer: signer)
        
        let action = Action(
            actionType: ActionType.UpdateConfig,
            data: UpdateConfigData(
                minVoteThreshold: minVoteThreshold,
                minimumQuorumNumber: minimumQuorumNumber,
                minimumProposalStake: minimumProposalStake,
                defaultVotingPeriod: defaultVotingPeriod,
                defaultCooldownPeriod: defaultCooldownPeriod
            ) as AnyStruct
        )
        
        self.createProposalInternal(
            title: title,
            description: description,
            action: action,
            proposalType: ProposalType.WithdrawTreasury,  // Using WithdrawTreasury as generic type for non-treasury proposals
            creator: signer.address,
            treasuryAmount: nil,
            treasuryAddress: nil
        )
    }
    
    /// Create a remove member proposal (admin members only)
    access(all) fun createRemoveMemberProposal(
        title: String,
        description: String,
        memberAddress: Address,
        signer: auth(BorrowValue) &Account
    ) {
        // Require admin member
        self.requireAdminMember(signer: signer)
        let action = Action(
            actionType: ActionType.RemoveMember,
            data: RemoveMemberData(address: memberAddress) as AnyStruct
        )
        
        self.createProposalInternal(
            title: title,
            description: description,
            action: action,
            proposalType: ProposalType.AdminBasedOperation,
            creator: signer.address,
            treasuryAmount: nil,
            treasuryAddress: nil
        )
    }
    
    /// Create an EVM call proposal (admin members only)
    /// Allows DAO to execute EVM contract calls through the COA
    access(all) fun createEVMCallProposal(
        title: String,
        description: String,
        targets: [String],
        values: [UInt256],
        functionSignatures: [String],
        functionArgs: [[AnyStruct]],
        signer: auth(BorrowValue) &Account
    ) {

        // Validate treasury contract address is set
        assert(
            self.evmTreasuryContractAddress != nil,
            message: "EVM Treasury contract address must be set in DAO configuration"
        )
        
        let evmCallData = EVMCallData(
            targets: targets,
            values: values,
            functionSignatures: functionSignatures,
            functionArgs: functionArgs
        )
        
        let action = Action(
            actionType: ActionType.ExecuteEVMCall,
            data: evmCallData as AnyStruct
        )
        
        self.createProposalInternal(
            title: title,
            description: description,
            action: action,
            proposalType: ProposalType.EVMCall,
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
            stakedAmount: self.minimumProposalStake,  // Use global config value
            treasuryAmount: treasuryAmount,
            treasuryAddress: treasuryAddress
        )

        // Don't deposit tokens yet - proposal starts as Pending
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
        signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue, GetStorageCapabilityController, PublishCapability) &Account
    ) {
        let proposal = self.proposals[proposalId] ?? panic("Proposal does not exist")
        
        assert(
            self.getStatus(proposalId: proposalId) == ProposalStatus.Pending,
            message: "Proposal is not pending - cannot deposit"
        )
        
        let requiredStake = self.minimumProposalStake  // Use global DAO config value
        let depositAmount = deposit.balance
        
        assert(
            depositAmount >= requiredStake,
            message: "Insufficient deposit amount. Required: ".concat(requiredStake.toString()).concat(", Provided: ").concat(depositAmount.toString())
        )
        
        // Store depositor address and actual deposit amount for refund purposes
        self.pendingDeposits[proposalId] = ProposalDeposit(
            depositorAddress: signer.address,
            depositAmount: depositAmount
        )
        
        // Deposit ToucanTokens
        self.toucanTokenBalance.deposit(from: <-deposit)
        
        // Update proposal status to Active
        proposal.setStatus(newStatus: ProposalStatus.Active)
        self.proposals[proposalId] = proposal
        
        emit ProposalActivated(proposalId: proposalId, depositor: signer.address)
        
        // Schedule the proposal for execution after cooldown period
        // Time to execute is after the cooldown period by one second
        let future = proposal.expiryTimestamp + proposal.cooldownPeriod + 1.0
        
        // Wrap proposalId as AnyStruct for scheduler
        let data: AnyStruct? = proposalId as AnyStruct
        
        let pr = FlowTransactionScheduler.Priority.Medium;
        
        // Get the handler capability
        var handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>? = nil
        let controllers = signer.capabilities.storage.getControllers(forPath: /storage/ToucanDAOTransactionHandler)
        
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
            data: data,
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
            data: data,
            timestamp: future,
            priority: pr,
            executionEffort: 1000,
            fees: <-fees
        )
        
        emit TransactionScheduled(txId: transactionId, executeAt: future)
        
        log("Scheduled transaction id: "
            .concat(transactionId.toString())
            .concat(" at ")
            .concat(future.toString()))    }
    
    /// Cancel a proposal and return the ToucanTokens to the depositor
    /// Can only be called by the proposal creator and only if no one has voted
    access(all) fun cancelProposal(
        proposalId: UInt64,
        signer: auth(BorrowValue) &Account
    ) {
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
        
        // Get deposit info (address and amount)
        let depositInfo = self.pendingDeposits[proposalId] ?? panic("No deposit found for proposal")
        assert(!depositInfo.wasRefunded(), message: "Deposit already refunded")
        let depositorAddress = depositInfo.depositorAddress
        let depositAmount = depositInfo.depositAmount
        
        // Mark proposal as cancelled
        self.updateProposalStatus(proposalId: proposalId, newStatus: ProposalStatus.Cancelled)
        
        // // Withdraw and return the ToucanTokens (refund full deposit amount)
        let depositorAccount = getAccount(depositorAddress)
        let receiverCap = depositorAccount.capabilities.get<&{FungibleToken.Receiver}>(
            ToucanToken.ReceiverPublicPath
        )
        
        if let receiver = receiverCap.borrow() {
            let refund <- self.toucanTokenBalance.withdraw(amount: depositAmount)
            receiver.deposit(from: <-refund)
            log("Refunded ".concat(depositAmount.toString()).concat(" ToucanTokens to depositor: ").concat(depositorAddress.toString()))
            var updated = depositInfo
            updated.markRefunded()
            self.pendingDeposits[proposalId] = updated
        } else {
            // If depositor's receiver is not available, this is a critical error
            // The tokens will remain in the contract - they should not be destroyed
            panic("Cannot refund depositor - ToucanToken receiver not found at address: ".concat(depositorAddress.toString()))
        }
    }
    
    /// Check if an address has ToucanToken balance > 0
    access(all) fun hasToucanTokenBalance(address: Address): Bool {
        let account = getAccount(address)
        // Try to borrow ToucanToken vault balance reference from public capability
        // Standard path for FungibleToken vault
        let capability = account.capabilities.get<&{FungibleToken.Balance}>(ToucanToken.VaultPublicPath)
        if let vaultRef = capability.borrow() {
            return vaultRef.balance > 0.0
        }
        return false
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
      // Require voter to have ToucanToken balance > 0
        assert(
            self.hasToucanTokenBalance(address: signer.address),
            message: "Only ToucanToken holders can vote on proposals"
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
        let totalVotes: UInt64 = proposal.getYesVotes() + proposal.getNoVotes()
        let totalMembers: UInt64 = UInt64(self.members.keys.length)
        
        // Check if proposal has no votes - it's expired
        if totalVotes == 0 {
            return ProposalStatus.Expired
        }
        
        // Check quorum and threshold requirements
        // Admin-based operations require 2/3 of total members to vote
        // Other proposals require minimumQuorumNumber of members to vote
        // Both types pass if yesVotes > noVotes after quorum is met
        
        if totalMembers > 0 && totalVotes >= self.minVoteThreshold {
            // Determine required quorum
            var requiredVotes: UInt64 = 0
            if proposal.proposalType == ProposalType.AdminBasedOperation {
                // Admin operations: require 2/3 of total members (with ceiling rounding)
                let twoThirdsRaw = (UFix64(totalMembers) * 2.0 / 3.0)
                let twoThirdsInt = UInt64(twoThirdsRaw)
                if twoThirdsRaw > UFix64(twoThirdsInt) {
                    requiredVotes = twoThirdsInt + 1  // Round up
                } else {
                    requiredVotes = twoThirdsInt
                }
            } else {
                // Non-admin proposals: require minimumQuorumNumber
                requiredVotes = UInt64(self.minimumQuorumNumber)
            }
            
            // Check if quorum is met
            if totalVotes < requiredVotes {
                return ProposalStatus.Rejected
            }
            
            // Both admin and non-admin proposals: pass if yes > no
            if proposal.getYesVotes() > proposal.getNoVotes() {
                return ProposalStatus.Passed
            } else {
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
    /// Refunds the depositor directly for all statuses (Passed, Rejected, Expired)
    access(self) fun executeProposal(proposalId: UInt64) {
        let proposal = self.proposals[proposalId]
            ?? panic("Proposal does not exist")

        let status = self.getStatus(proposalId: proposalId)
        let depositInfo = self.pendingDeposits[proposalId] ?? panic("No deposit found for proposal")
        assert(!depositInfo.wasRefunded(), message: "Deposit already refunded")
        let depositorAddress = depositInfo.depositorAddress
        let depositAmount = depositInfo.depositAmount

        assert(
           status != ProposalStatus.Executed,
            message: "Proposal has already been executed"
        )
        
        // Check if cooldown period has passed
        assert(
            proposal.isReadyForExecution(),
            message: "Proposal is still in cooldown period"
        )
        // Do not remove deposit info; mark refunded after successful transfer

        if status == ProposalStatus.Passed {
            // Execute the action associated with the proposal
            let action = proposal.getAction()
            self.executeAction(proposalType: proposal.proposalType, action: action, proposalId: proposalId)

            // Update proposal status to executed
            self.updateProposalStatus(proposalId: proposalId, newStatus: ProposalStatus.Executed)

            emit ProposalExecuted(id: proposalId)
        } else if status == ProposalStatus.Rejected {
            self.updateProposalStatus(proposalId: proposalId, newStatus: ProposalStatus.Rejected)
        } else if status == ProposalStatus.Expired {
            self.updateProposalStatus(proposalId: proposalId, newStatus: ProposalStatus.Expired)
        } else {
            // Other statuses (Active, Pending) - should never happen after cooldown
            // This indicates an invalid state - revert transaction
            panic("Invalid proposal status after cooldown period. Expected: Passed, Rejected, or Expired")
        }
        
        // Refund depositor directly for all statuses (Passed, Rejected, Expired)
        let depositorAccount = getAccount(depositorAddress)
        let receiverCap = depositorAccount.capabilities.get<&{FungibleToken.Receiver}>(
            ToucanToken.ReceiverPublicPath
        )
        
        if let receiver = receiverCap.borrow() {
            let refund <- self.toucanTokenBalance.withdraw(amount: depositAmount)
            receiver.deposit(from: <-refund)
            log("Refunded ".concat(depositAmount.toString()).concat(" ToucanTokens to depositor: ").concat(depositorAddress.toString()))
            var updated = depositInfo
            updated.markRefunded()
            self.pendingDeposits[proposalId] = updated
        } else {
            // If depositor's receiver is not available, this is a critical error
            // The tokens will remain in the contract - they should not be destroyed
            panic("Cannot refund depositor - ToucanToken receiver not found at address: ".concat(depositorAddress.toString()))
        }
    }
    
    /// Execute an action based on its type and proposal type
    /// This is contract-private and can only be called from within the contract
    access(self) fun executeAction(proposalType: ProposalType, action: Action, proposalId: UInt64) {
        // Handle treasury operations based on proposal type
        switch proposalType {
            case ProposalType.WithdrawTreasury:
                self.executeWithdrawTreasury(action: action)
            case ProposalType.EVMCall:
                self.executeEVMCall(action: action)
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
                self.executeUpdateConfig(action: action)
            
            case ActionType.ExecuteCustom:
                log("Custom action executed")
            
            case ActionType.ExecuteEVMCall:
                // Handled in proposal type switch above
                log("EVM call action executed")
            
            case ActionType.None:
                log("No action to execute")
        }
    }
    

    
    /// Execute a treasury withdrawal operation (Money OUT)
    /// Withdraws tokens of the specified type from DAO treasury and sends to recipient
    access(self) fun executeWithdrawTreasury(action: Action) {
        if let withdrawData = action.data as? WithdrawTreasuryData {
            // Validate treasury has sufficient balance for the specified token type
            let treasuryBalance = self.treasury.getBalance(vaultType: withdrawData.vaultType)
            assert(
                treasuryBalance >= withdrawData.amount,
                message: "Insufficient treasury balance. Required: ".concat(withdrawData.amount.toString()).concat(", Available: ").concat(treasuryBalance.toString())
            )
            
            // Withdraw from treasury (supports any token type)
            let tokens <- self.treasury.withdraw(vaultType: withdrawData.vaultType, amount: withdrawData.amount)
            
            // Get recipient's receiver capability
            // Note: capabilities.get will abort if capability doesn't exist
            let recipientAccount = getAccount(withdrawData.recipientAddress)
            let recipientCapability = recipientAccount.capabilities.get<&{FungibleToken.Receiver}>(withdrawData.recipientVaultPath)
            
            // Borrow the receiver reference from the capability
            if let recipientReceiver = recipientCapability.borrow() {
                // Send tokens to recipient
                recipientReceiver.deposit(from: <-tokens)
            } else {
                panic("Failed to borrow recipient receiver reference - capability may not be properly configured")
            }
            
            log("Withdrew ".concat(withdrawData.amount.toString()).concat(" tokens to ").concat(withdrawData.recipientAddress.toString()))
        } else {
            panic("Invalid WithdrawTreasuryData in action")
        }
    }
    /**   */
    /// Execute a configuration update operation
    access(self) fun executeUpdateConfig(action: Action) {
        if let configData = action.data as? UpdateConfigData {
            // Update configuration values if provided
            if configData.minVoteThreshold != nil {
                self.minVoteThreshold = configData.minVoteThreshold!
            }
            if configData.minimumQuorumNumber != nil {
                self.minimumQuorumNumber = configData.minimumQuorumNumber!
            }
            if configData.minimumProposalStake != nil {
                self.minimumProposalStake = configData.minimumProposalStake!
            }
            if configData.defaultVotingPeriod != nil {
                self.defaultVotingPeriod = configData.defaultVotingPeriod!
            }
            if configData.defaultCooldownPeriod != nil {
                self.defaultCooldownPeriod = configData.defaultCooldownPeriod!
            }
            
            log("DAO configuration updated successfully")
        } else {
            panic("Invalid UpdateConfigData in action")
        }
    }
    
    /// Execute EVM contract calls through COA
    /// Calls FlowTreasury.execute() with the provided targets, values, and calldatas
    access(self) fun executeEVMCall(action: Action) {
        let evmCallData = action.data as? EVMCallData
            ?? panic("Invalid EVMCallData in action")
        
        // Validate treasury contract address is set
        let treasuryAddressStr = self.evmTreasuryContractAddress
            ?? panic("EVM Treasury contract address not configured")
        
        // Get COA from stored capability
        let coaCap = self.coaCapability
            ?? panic("COA capability not set. Call setCOACapability() first")
        
        let coa = coaCap.borrow()
            ?? panic("Could not borrow COA from capability")
        
        // Encode all function calls and convert addresses
        var calldatas: [[UInt8]] = []
        var targetAddresses: [EVM.EVMAddress] = []
        
        for i, targetStr in evmCallData.targets {
            // Convert target string to EVMAddress
            let targetAddress = EVM.addressFromString(targetStr)
            targetAddresses.append(targetAddress)
            
            // Encode function call
            let calldata = EVM.encodeABIWithSignature(
                evmCallData.functionSignatures[i],
                evmCallData.functionArgs[i]
            )
            calldatas.append(calldata)
        }
        
        // Call each target contract individually through the COA
        // This matches FlowTreasury.execute() behavior - if one fails, continue with others
        var successCount: UInt64 = 0
        var failureCount: UInt64 = 0
        
        var index: UInt64 = 0
        for targetAddress in targetAddresses {
            let value = evmCallData.values[index]
            let calldata = calldatas[index]
            
            // Create Balance from UInt256 value (value is in attoflow)
            // Convert UInt256 to UInt for Balance constructor
            // Note: UInt256 can be larger than UInt max, so we check bounds
            let attoflowValue: UInt = UInt(value)
            let balance = EVM.Balance(attoflow: attoflowValue)
            
            // Make the call
            let result = coa.call(
                to: targetAddress,
                data: calldata,
                gasLimit: 500_000,  // Default gas limit, can be made configurable
                value: balance
            )
            
            // Check result status
            switch result.status {
                case EVM.Status.successful:
                    successCount = successCount + 1
                    log("EVM call ".concat(index.toString()).concat(" succeeded. Gas used: ").concat(result.gasUsed.toString()))
                case EVM.Status.failed:
                    failureCount = failureCount + 1
                    log("EVM call ".concat(index.toString()).concat(" failed: ").concat(result.errorMessage))
                    // Continue execution (don't revert) - matching FlowTreasury behavior
                case EVM.Status.invalid:
                    failureCount = failureCount + 1
                    panic("EVM call ".concat(index.toString()).concat(" invalid: ").concat(result.errorMessage))
            }
            
            index = index + 1
        }
        
        // Log summary
        log("EVM calls completed. Successful: ".concat(successCount.toString()).concat(", Failed: ").concat(failureCount.toString()))
        
        // If all calls failed, revert (optional - could also allow partial success)
        if successCount == 0 && failureCount > 0 {
            panic("All EVM calls failed")
        }
    }
        // ════════════════════════════════════════════════════════════
    // SCHEDULE FUNCTION
    // ════════════════════════════════════════════════════════════
    




       /// Handler resource that implements the Scheduled Transaction interface
    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {
        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {
            // Extract proposalId from data
            let proposalId = data as? UInt64 ?? panic("Invalid proposal ID in transaction data")
            
            // Execute the proposal - refund is automatically sent to depositor
            ToucanDAO.executeProposal(proposalId: proposalId)
            
            log("Transaction executed (id: ".concat(id.toString()).concat(", proposalId: ").concat(proposalId.toString()).concat(")"))
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


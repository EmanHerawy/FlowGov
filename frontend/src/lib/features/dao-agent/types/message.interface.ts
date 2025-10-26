export interface AgentMessage {
	id: string;
	role: 'user' | 'assistant' | 'system';
	content: string;
	timestamp: Date;
	isLoading?: boolean;
	error?: string;
}

export interface DaoContext {
	projectId?: string;
	projectName?: string;
	tokenSymbol?: string;
	totalSupply?: string;
	currentProposals?: any[];
	votingRounds?: any[];
	userBalance?: number;
	userAddress?: string;
}

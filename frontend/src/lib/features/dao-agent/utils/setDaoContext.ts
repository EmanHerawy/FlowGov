import { agentStore } from '../stores/AgentStore';
import type { DaoContext } from '../types/message.interface';
import type { DAOProject } from '$lib/types/dao-project/dao-project.interface';

/**
 * Sets the DAO context for the AI agent based on the current DAO project
 * This allows the agent to provide contextual answers about the specific DAO
 */
export function setDaoContextFromProject(daoData: DAOProject, userAddress?: string) {
	const context: DaoContext = {
		projectId: daoData.generalInfo.project_id,
		projectName: daoData.generalInfo.name,
		tokenSymbol: daoData.generalInfo.token_symbol,
		totalSupply: daoData.onChainData.totalSupply,
		currentProposals: daoData.onChainData.actions,
		votingRounds: daoData.votingRounds,
		userBalance: daoData.userBalance,
		userAddress: userAddress
	};

	agentStore.setDaoContext(context);
}

/**
 * Clears the DAO context when leaving a project page
 */
export function clearDaoContext() {
	agentStore.setDaoContext(null);
}

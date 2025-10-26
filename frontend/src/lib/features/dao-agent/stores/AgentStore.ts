import { writable } from 'svelte/store';
import type { AgentMessage, DaoContext } from '../types/message.interface';

interface AgentState {
	messages: AgentMessage[];
	isOpen: boolean;
	isLoading: boolean;
	daoContext: DaoContext | null;
}

function createAgentStore() {
	const { subscribe, set, update } = writable<AgentState>({
		messages: [],
		isOpen: false,
		isLoading: false,
		daoContext: null
	});

	return {
		subscribe,
		open: () => update(state => ({ ...state, isOpen: true })),
		close: () => update(state => ({ ...state, isOpen: false })),
		toggle: () => update(state => ({ ...state, isOpen: !state.isOpen })),
		
		setDaoContext: (context: DaoContext) => update(state => ({ 
			...state, 
			daoContext: context 
		})),
		
		addMessage: (message: Omit<AgentMessage, 'id' | 'timestamp'>) => update(state => ({
			...state,
			messages: [
				...state.messages,
				{
					...message,
					id: crypto.randomUUID(),
					timestamp: new Date()
				}
			]
		})),
		
		setLoading: (isLoading: boolean) => update(state => ({ 
			...state, 
			isLoading 
		})),
		
		updateLastMessage: (updates: Partial<AgentMessage>) => update(state => {
			const messages = [...state.messages];
			if (messages.length > 0) {
				messages[messages.length - 1] = {
					...messages[messages.length - 1],
					...updates
				};
			}
			return { ...state, messages };
		}),
		
		clearMessages: () => update(state => ({ 
			...state, 
			messages: [] 
		})),
		
		reset: () => set({
			messages: [],
			isOpen: false,
			isLoading: false,
			daoContext: null
		})
	};
}

export const agentStore = createAgentStore();

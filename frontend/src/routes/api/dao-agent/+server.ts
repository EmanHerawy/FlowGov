import { env as PrivateEnv } from '$env/dynamic/private';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

// This endpoint keeps the LLM API key secure on the server side
// NEVER expose API keys to the frontend
export const POST: RequestHandler = async ({ request }) => {
	try {
		const { messages, daoContext } = await request.json();

		// Validate request
		if (!messages || !Array.isArray(messages)) {
			return json({ error: 'Invalid messages format' }, { status: 400 });
		}

		// Get API key from environment variables (server-side only)
		const apiKey = PrivateEnv.OPENAI_API_KEY || PrivateEnv.ANTHROPIC_API_KEY;
		
		if (!apiKey) {
			console.error('No LLM API key configured');
			return json({ error: 'AI service not configured' }, { status: 503 });
		}

		// Build system prompt for DAO expert
		const systemPrompt = buildDaoExpertPrompt(daoContext);

		// Call LLM API (example using OpenAI-compatible endpoint)
		const response = await callLLM(apiKey, systemPrompt, messages);

		return json({ 
			message: response,
			success: true 
		});

	} catch (error) {
		console.error('DAO Agent API Error:', error);
		return json({ 
			error: 'Failed to process request',
			details: error instanceof Error ? error.message : 'Unknown error'
		}, { status: 500 });
	}
};

function buildDaoExpertPrompt(daoContext?: any): string {
	const basePrompt = `You are a DAO Governance Expert Assistant for FlowGov, a governance platform built on the Flow blockchain.

Your role is to help users understand and navigate DAO governance, including:
- Explaining governance proposals and their implications
- Guiding users through voting processes
- Explaining token delegation mechanisms
- Providing insights on proposal voting history and outcomes
- Helping users understand treasury management
- Explaining multisig operations and thresholds
- Clarifying voting rounds and their parameters

Key principles:
1. Be clear, concise, and educational
2. Always explain blockchain concepts in simple terms
3. Encourage informed decision-making
4. Never make investment recommendations
5. Always remind users to verify information on-chain
6. Explain the risks and benefits of governance actions

When discussing voting:
- Explain what the proposal does in simple terms
- Highlight key parameters and their implications
- Explain voting power and how it's calculated
- Describe the voting period and quorum requirements

When discussing delegation:
- Explain what delegation means and its implications
- Clarify that delegated tokens can be reclaimed
- Explain how delegation affects voting power
- Describe the responsibilities of delegates`;

	if (daoContext) {
		return `${basePrompt}

Current DAO Context:
${JSON.stringify(daoContext, null, 2)}

Use this context to provide specific, relevant answers about the current DAO state.`;
	}

	return basePrompt;
}

async function callLLM(apiKey: string, systemPrompt: string, messages: any[]): Promise<string> {
	// Determine which LLM service to use based on available API key
	const isOpenAI = PrivateEnv.OPENAI_API_KEY;
	const isAnthropic = PrivateEnv.ANTHROPIC_API_KEY;

	if (isOpenAI) {
		return callOpenAI(apiKey, systemPrompt, messages);
	} else if (isAnthropic) {
		return callAnthropic(apiKey, systemPrompt, messages);
	} else {
		throw new Error('No supported LLM service configured');
	}
}

async function callOpenAI(apiKey: string, systemPrompt: string, messages: any[]): Promise<string> {
	const response = await fetch('https://api.openai.com/v1/chat/completions', {
		method: 'POST',
		headers: {
			'Content-Type': 'application/json',
			'Authorization': `Bearer ${apiKey}`
		},
		body: JSON.stringify({
			model: 'gpt-4o-mini', // Using cost-effective model
			messages: [
				{ role: 'system', content: systemPrompt },
				...messages
			],
			temperature: 0.7,
			max_tokens: 1000
		})
	});

	if (!response.ok) {
		const error = await response.text();
		throw new Error(`OpenAI API error: ${error}`);
	}

	const data = await response.json();
	return data.choices[0].message.content;
}

async function callAnthropic(apiKey: string, systemPrompt: string, messages: any[]): Promise<string> {
	const response = await fetch('https://api.anthropic.com/v1/messages', {
		method: 'POST',
		headers: {
			'Content-Type': 'application/json',
			'x-api-key': apiKey,
			'anthropic-version': '2023-06-01'
		},
		body: JSON.stringify({
			model: 'claude-3-haiku-20240307', // Using cost-effective model
			max_tokens: 1000,
			system: systemPrompt,
			messages: messages
		})
	});

	if (!response.ok) {
		const error = await response.text();
		throw new Error(`Anthropic API error: ${error}`);
	}

	const data = await response.json();
	return data.content[0].text;
}

import * as fcl from '@onflow/fcl';
import dappInfo from '$lib/config/config';
import { env } from '$env/dynamic/public';

const resolver = async () => {
	// const response = await fetch('/api/generate');
	const nonce = '7f190deedcd3b0538b7cd0ebc1994ed40d9db16cc1a6fcc3e7a994240c14d86d';
	return {
		appIdentifier: 'FlowGov',
		nonce
	};
};

export const network: 'mainnet' | 'testnet' | 'emulator' = env.PUBLIC_FLOW_NETWORK as
	| 'mainnet'
	| 'testnet'
	| 'emulator';

const fclConfigInfo = {
	emulator: {
		accessNode: 'http://127.0.0.1:8888',
		discoveryWallet: 'http://localhost:8701/fcl/authn',
		discoveryAuthnInclude: []
	},
	testnet: {
		accessNode: 'https://rest-testnet.onflow.org',
		discoveryWallet: 'https://fcl-discovery.onflow.org/testnet/authn',
		discoveryAuthnInclude: ['0x82ec283f88a62e65', '0x9d2e44203cb13051'],
		discoveryAuthnEndpoint: 'https://fcl-discovery.onflow.org/api/testnet/authn'
	},
	mainnet: {
		accessNode: 'https://rest-mainnet.onflow.org',
		discoveryWallet: 'https://fcl-discovery.onflow.org/authn',
		discoveryAuthnInclude: ['0xead892083b3e2c6c', '0xe5cd26afebe62781'],
		discoveryAuthnEndpoint: 'https://fcl-discovery.onflow.org/api/authn'
	}
};

// Get the app URL - use window.location.origin in browser, fallback for SSR
const getAppUrl = () => {
	if (typeof window !== 'undefined') {
		return window.location.origin;
	}
	return 'http://localhost:5173';
};

const config = fcl.config()
	.put('app.detail.title', dappInfo.title)
	.put('app.detail.icon', dappInfo.icon)
	.put('app.detail.url', getAppUrl())
	.put('fcl.accountProof.resolver', resolver)
	.put('flow.network', network)
	.put('accessNode.api', fclConfigInfo[network].accessNode)
	.put('discovery.wallet', fclConfigInfo[network].discoveryWallet)
	.put('discovery.authn.include', fclConfigInfo[network].discoveryAuthnInclude);

// Add discovery.authn.endpoint for testnet and mainnet to fix CORS issues
if (network !== 'emulator' && fclConfigInfo[network].discoveryAuthnEndpoint) {
	config.put('discovery.authn.endpoint', fclConfigInfo[network].discoveryAuthnEndpoint);
}

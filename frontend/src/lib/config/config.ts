import { browser } from '$app/environment';

const dappInfo = {
	title: 'FlowGov',
	description:
		'Create a token. Unlock transparent fundraising and voting. Manage funds thorough a secure multisig treasury.',
	url: browser ? window.location.origin : 'http://localhost:5173',
	author: 'FlowGov Team',
	icon: 'https://i.imgur.com/cQPEJBg.png'
};

export default dappInfo;

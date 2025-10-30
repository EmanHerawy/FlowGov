const FLOWGOV_STATS = {
	data1: { title: 'DAOs Created', stat: undefined },
	data2: { title: 'Total Market Cap', stat: '+100k' },
	data3: { title: 'Funds Raised', stat: '+15k' }
};

export const getFlowGovStats = (numberOfProjects: number) => {
	return {
		...FLOWGOV_STATS,
		data1: {
			...FLOWGOV_STATS.data1,
			stat: numberOfProjects.toString()
		}
	};
};

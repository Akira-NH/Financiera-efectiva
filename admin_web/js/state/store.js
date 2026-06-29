export const state = {
  user: null,
  role: "",
  roleProfile: null,
  selectedKey: null,
  unsubscribers: [],
  loading: false,
  error: "",
  actionMessage: "",
  requests: [],
  demoClients: [],
  salesClients: [],
  clientProfile: null,
  clientRequests: [],
  activeLoan: null,
  installments: [],
  clientLocation: null,
  filters: {
    search: "",
    status: "all",
    visit: "all",
    source: "all",
    advisor: "",
    date: "",
  },
};

export function clearSessionData() {
  state.requests = [];
  state.demoClients = [];
  state.salesClients = [];
  state.clientProfile = null;
  state.clientRequests = [];
  state.activeLoan = null;
  state.installments = [];
  state.clientLocation = null;
  state.selectedKey = null;
  state.actionMessage = "";
  state.error = "";
}

export function cleanupListeners() {
  for (const unsubscribe of state.unsubscribers) unsubscribe();
  state.unsubscribers = [];
}

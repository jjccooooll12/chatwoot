import types from '../mutation-types';
import ConversationApi from '../../api/inbox/conversation';

// Every bucket the "CHATS" sidebar can show. Keeping this in sync with
// Conversation::CHAT_LANGUAGES (backend) is enforced by the counts response
// itself always containing all seven keys.
export const CHAT_LANGUAGES = [
  'us',
  'italian',
  'french',
  'spanish',
  'german',
  'dutch',
  'polish',
];

const state = {
  counts: {},
};

export const getters = {
  getChatLanguageCounts: $state => $state.counts,
};

export const actions = {
  get: async ({ commit }) => {
    try {
      const { data } = await ConversationApi.getChatLanguageCounts();
      commit(types.SET_CHAT_LANGUAGE_COUNTS, data);
    } catch (error) {
      // ignore, sidebar just shows stale/zero counts until the next poll
    }
  },
};

export const mutations = {
  [types.SET_CHAT_LANGUAGE_COUNTS]($state, counts = {}) {
    $state.counts = counts;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};

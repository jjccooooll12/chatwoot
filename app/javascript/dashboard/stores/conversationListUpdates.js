import { defineStore } from 'pinia';

// FRESHDESK-SKIN: changes made by someone other than the signed-in agent
// (customer emails, other agents, background jobs) must not reshuffle the
// ticket list under them. The websocket handlers still apply those changes to
// the conversations store, but also hold the conversation ids here; the ticket
// list keeps held tickets where they were and offers an "N updates" pill.
export const useConversationListUpdatesStore = defineStore(
  'conversationListUpdates',
  {
    state: () => ({
      conversationIds: [],
    }),

    actions: {
      hold(conversationId) {
        if (this.conversationIds.includes(conversationId)) return;
        this.conversationIds.push(conversationId);
      },

      release() {
        this.conversationIds = [];
      },
    },
  }
);

<script>
import { mapGetters } from 'vuex';
import ConversationHeader from './ConversationHeader.vue';
import DashboardAppFrame from '../DashboardApp/Frame.vue';
import EmptyState from './EmptyState/EmptyState.vue';
import CannedResponsesPanel from './CannedResponsesPanel.vue';
import FreshdeskContactInfo from './FreshdeskContactInfo.vue';
import FreshdeskTicketProperties from './FreshdeskTicketProperties.vue';
import FreshdeskTicketTitle from './FreshdeskTicketTitle.vue';
import MessagesView from './MessagesView.vue';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

export default {
  components: {
    ConversationHeader,
    DashboardAppFrame,
    EmptyState,
    CannedResponsesPanel,
    FreshdeskContactInfo,
    FreshdeskTicketProperties,
    FreshdeskTicketTitle,
    MessagesView,
  },
  props: {
    inboxId: {
      type: [Number, String],
      default: '',
      required: false,
    },
    isInboxView: {
      type: Boolean,
      default: false,
    },
    isContactPanelOpen: {
      type: Boolean,
      default: true,
    },
    isOnExpandedLayout: {
      type: Boolean,
      default: true,
    },
  },
  data() {
    return { activeIndex: 0, showCannedResponsesPanel: false };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      dashboardApps: 'dashboardApps/getRecords',
    }),
    dashboardAppTabs() {
      return [
        {
          key: 'messages',
          index: 0,
          name: this.$t('CONVERSATION.DASHBOARD_APP_TAB_MESSAGES'),
        },
        ...this.dashboardApps.map((dashboardApp, index) => ({
          key: `dashboard-${dashboardApp.id}`,
          index: index + 1,
          name: dashboardApp.title,
        })),
      ];
    },
    showContactPanel() {
      return this.isContactPanelOpen && this.currentChat.id;
    },
  },
  watch: {
    'currentChat.inbox_id': {
      immediate: true,
      handler(inboxId) {
        if (inboxId) {
          this.$store.dispatch('inboxAssignableAgents/fetch', {
            inboxIds: [inboxId],
            includeAgentBots: true,
          });
        }
      },
    },
    'currentChat.id'() {
      this.fetchLabels();
      this.activeIndex = 0;
      this.showCannedResponsesPanel = false;
    },
  },
  mounted() {
    this.fetchLabels();
    this.$store.dispatch('dashboardApps/get');
    emitter.on(
      BUS_EVENTS.TOGGLE_CANNED_RESPONSES_PANEL,
      this.toggleCannedResponsesPanel
    );
  },
  beforeUnmount() {
    emitter.off(
      BUS_EVENTS.TOGGLE_CANNED_RESPONSES_PANEL,
      this.toggleCannedResponsesPanel
    );
  },
  methods: {
    toggleCannedResponsesPanel() {
      this.showCannedResponsesPanel = !this.showCannedResponsesPanel;
    },
    fetchLabels() {
      if (!this.currentChat.id) {
        return;
      }
      this.$store.dispatch('conversationLabels/get', this.currentChat.id);
    },
    onDashboardAppTabChange(index) {
      this.activeIndex = index;
    },
  },
};
</script>

<template>
  <div
    class="conversation-details-wrap flex flex-col min-w-0 w-full bg-fd-background relative"
    :class="{
      'border-l rtl:border-l-0 rtl:border-r border-n-weak': !isOnExpandedLayout,
    }"
  >
    <ConversationHeader
      v-if="currentChat.id"
      :chat="currentChat"
      :show-back-button="isOnExpandedLayout && !isInboxView"
      :class="{
        'border-b border-b-n-weak': !dashboardApps.length,
      }"
    />
    <woot-tabs
      v-if="dashboardApps.length && currentChat.id"
      :index="activeIndex"
      class="h-10"
      @change="onDashboardAppTabChange"
    >
      <woot-tabs-item
        v-for="tab in dashboardAppTabs"
        :key="tab.key"
        :index="tab.index"
        :name="tab.name"
        :show-badge="false"
        is-compact
      />
    </woot-tabs>
    <div v-show="!activeIndex" class="flex h-full min-h-0 m-0">
      <div class="flex min-w-0 flex-1 flex-col bg-fd-surface">
        <FreshdeskTicketTitle v-if="currentChat.id" :chat="currentChat" />
        <MessagesView
          v-if="currentChat.id"
          :inbox-id="inboxId"
          :is-inbox-view="isInboxView"
        />
      </div>
      <CannedResponsesPanel
        v-if="currentChat.id && showCannedResponsesPanel"
        @close="showCannedResponsesPanel = false"
      />
      <template v-else>
        <FreshdeskTicketProperties v-if="currentChat.id" :chat="currentChat" />
        <FreshdeskContactInfo v-if="currentChat.id" :chat="currentChat" />
      </template>
      <EmptyState
        v-if="!currentChat.id && !isInboxView"
        :is-on-expanded-layout="isOnExpandedLayout"
      />
      <slot />
    </div>
    <DashboardAppFrame
      v-for="(dashboardApp, index) in dashboardApps"
      v-show="activeIndex - 1 === index"
      :key="currentChat.id + '-' + dashboardApp.id"
      :is-visible="activeIndex - 1 === index"
      :config="dashboardApps[index].content"
      :position="index"
      :current-chat="currentChat"
    />
  </div>
</template>

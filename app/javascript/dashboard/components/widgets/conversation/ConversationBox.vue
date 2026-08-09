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
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
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
    Spinner,
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
    return {
      activeIndex: 0,
      showCannedResponsesPanel: false,
      isTicketBodyReady: false,
      revealFrame: null,
    };
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
    hasCurrentChat() {
      return Boolean(this.currentChat.id);
    },
    isCurrentChatDataReady() {
      return this.hasCurrentChat && this.currentChat.dataFetched !== undefined;
    },
    shouldShowTicketBody() {
      return this.hasCurrentChat && this.isTicketBodyReady;
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
      this.resetTicketBodyReveal();
      this.scheduleTicketBodyReveal();
    },
    'currentChat.dataFetched': {
      immediate: true,
      handler() {
        this.scheduleTicketBodyReveal();
      },
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
    this.cancelTicketBodyReveal();
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
    cancelTicketBodyReveal() {
      if (this.revealFrame) {
        cancelAnimationFrame(this.revealFrame);
        this.revealFrame = null;
      }
    },
    resetTicketBodyReveal() {
      this.cancelTicketBodyReveal();
      this.isTicketBodyReady = false;
    },
    scheduleTicketBodyReveal() {
      if (!this.hasCurrentChat) {
        this.resetTicketBodyReveal();
        return;
      }

      if (!this.isCurrentChatDataReady || this.isTicketBodyReady) {
        return;
      }

      this.$nextTick(() => {
        this.cancelTicketBodyReveal();
        this.revealFrame = requestAnimationFrame(() => {
          this.revealFrame = null;
          this.isTicketBodyReady = true;
        });
      });
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
    <template v-if="shouldShowTicketBody">
      <ConversationHeader
        :chat="currentChat"
        :show-back-button="isOnExpandedLayout && !isInboxView"
        :class="{
          'border-b border-b-n-weak': !dashboardApps.length,
        }"
      />
      <woot-tabs
        v-if="dashboardApps.length"
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
          <FreshdeskTicketTitle :chat="currentChat" />
          <MessagesView :inbox-id="inboxId" :is-inbox-view="isInboxView" />
        </div>
        <CannedResponsesPanel
          v-if="showCannedResponsesPanel"
          @close="showCannedResponsesPanel = false"
        />
        <template v-else>
          <FreshdeskTicketProperties :chat="currentChat" />
          <FreshdeskContactInfo :chat="currentChat" />
        </template>
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
    </template>
    <div
      v-else-if="hasCurrentChat"
      class="flex h-full items-center justify-center bg-fd-surface text-fd-muted"
    >
      <Spinner class="text-fd-primary" />
    </div>
    <div v-else class="flex h-full min-h-0 m-0">
      <EmptyState
        v-if="!isInboxView"
        :is-on-expanded-layout="isOnExpandedLayout"
      />
      <slot />
    </div>
  </div>
</template>

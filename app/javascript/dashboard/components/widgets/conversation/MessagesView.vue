<script>
import { ref, provide, useTemplateRef } from 'vue';
import { useElementSize } from '@vueuse/core';
// composable
import { useLabelSuggestions } from 'dashboard/composables/useLabelSuggestions';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';

// components
import ReplyBox from './ReplyBox.vue';
import MessageList from 'next/message/MessageList.vue';
import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';
import ConversationLabelSuggestion from './conversation/LabelSuggestion.vue';
import Banner from 'dashboard/components/ui/Banner.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ResizableEditorWrapper from './ResizableEditorWrapper.vue';
import SendAsEmailDialog from './SendAsEmailDialog.vue';

// stores and apis
import { mapGetters } from 'vuex';

// mixins
import inboxMixin, { INBOX_FEATURES } from 'shared/mixins/inboxMixin';

// utils
import { emitter } from 'shared/helpers/mitt';
import { getTypingUsersText } from '../../../helper/commons';
import { calculateScrollTop } from './helpers/scrollTopCalculationHelper';
import { LocalStorage } from 'shared/helpers/localStorage';
import {
  filterDuplicateSourceMessages,
  getReadMessages,
  getUnreadMessages,
} from 'dashboard/helper/conversationHelper';

// constants
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { REPLY_POLICY } from 'shared/constants/links';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import { CONTENT_TYPES } from 'next/message/constants';
import wootConstants from 'dashboard/constants/globals';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

export default {
  components: {
    MessageList,
    ReplyBox,
    Banner,
    ConversationLabelSuggestion,
    Spinner,
    ResizableEditorWrapper,
    SendAsEmailDialog,
  },
  mixins: [inboxMixin],
  setup() {
    const conversationPanelRef = ref(null);
    const resizableEditorWrapperRef = ref(null);
    const replyBoxRef = ref(null);
    const sendAsEmailDialogRef = ref(null);
    const messagesViewRef = useTemplateRef('messagesViewRef');
    const topBannerRef = useTemplateRef('topBannerRef');
    const { height: containerHeight } = useElementSize(messagesViewRef);
    const { height: topBannerHeight } = useElementSize(topBannerRef);

    const {
      captainTasksEnabled,
      isLabelSuggestionFeatureEnabled,
      getLabelSuggestions,
    } = useLabelSuggestions();

    provide('contextMenuElementTarget', conversationPanelRef);

    return {
      captainTasksEnabled,
      getLabelSuggestions,
      isLabelSuggestionFeatureEnabled,
      conversationPanelRef,
      resizableEditorWrapperRef,
      replyBoxRef,
      sendAsEmailDialogRef,
      messagesViewRef,
      topBannerRef,
      containerHeight,
      topBannerHeight,
    };
  },
  data() {
    return {
      isLoadingPrevious: true,
      heightBeforeLoad: null,
      conversationPanel: null,
      hasUserScrolled: false,
      isProgrammaticScroll: false,
      messageSentSinceOpened: false,
      labelSuggestions: [],
      // Freshdesk behaviour: the reply composer stays hidden until the agent
      // clicks Reply / Note / Forward in the ticket toolbar.
      composerOpen: false,
      // Activity log lines (status/priority/assignment changes) are hidden from
      // the thread by default and only revealed via the toolbar's Activities button.
      showActivities: false,
    };
  },

  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      currentUserId: 'getCurrentUserID',
      currentUser: 'getCurrentUser',
      listLoadingStatus: 'getAllMessagesLoaded',
      currentAccountId: 'getCurrentAccountId',
    }),
    composerAvatarInitial() {
      const user = this.currentUser || {};
      return (user.name || user.email || 'U').charAt(0).toUpperCase();
    },
    isOpen() {
      return this.currentChat?.status === wootConstants.STATUS_TYPE.OPEN;
    },
    shouldShowLabelSuggestions() {
      return (
        this.isOpen &&
        this.captainTasksEnabled &&
        this.isLabelSuggestionFeatureEnabled &&
        !this.messageSentSinceOpened
      );
    },
    inboxId() {
      return this.currentChat.inbox_id;
    },
    inbox() {
      return this.$store.getters['inboxes/getInbox'](this.inboxId);
    },
    typingUsersList() {
      const userList = this.$store.getters[
        'conversationTypingStatus/getUserList'
      ](this.currentChat.id);
      return userList;
    },
    isAnyoneTyping() {
      const userList = this.typingUsersList;
      return userList.length !== 0;
    },
    typingUserNames() {
      const userList = this.typingUsersList;
      if (this.isAnyoneTyping) {
        const [i18nKey, params] = getTypingUsersText(userList);
        return this.$t(i18nKey, params);
      }

      return '';
    },
    getMessages() {
      const allMessages = this.currentChat.messages || [];
      const messages = this.showActivities
        ? allMessages
        : allMessages.filter(
            m =>
              m.message_type !== MESSAGE_TYPE.ACTIVITY ||
              m.content_attributes?.activity?.type === 'conversation_merged'
          );
      if (this.isAWhatsAppChannel) {
        return filterDuplicateSourceMessages(messages);
      }
      return messages;
    },
    // A voice ticket reads top-down like an email/ticket thread (the call
    // summary is the one thing that matters, not a running back-and-forth),
    // so it shouldn't get the chat-style "first:mt-auto" trick further down
    // that bottom-anchors short conversations near the composer - that left
    // a lone call card stranded at the very bottom with a large empty gap
    // above it instead of sitting in its natural top-of-thread position.
    isVoiceCallConversation() {
      return (this.currentChat.messages || []).some(
        m => m.content_type === CONTENT_TYPES.VOICE_CALL
      );
    },
    readMessages() {
      return getReadMessages(
        this.getMessages,
        this.currentChat.agent_last_seen_at
      );
    },
    unReadMessages() {
      return getUnreadMessages(
        this.getMessages,
        this.currentChat.agent_last_seen_at
      );
    },
    shouldShowSpinner() {
      return (
        (this.currentChat && this.currentChat.dataFetched === undefined) ||
        (!this.listLoadingStatus && this.isLoadingPrevious)
      );
    },
    // Check there is a instagram inbox exists with the same instagram_id
    hasDuplicateInstagramInbox() {
      const instagramId = this.inbox.instagram_id;
      const { additional_attributes: additionalAttributes = {} } = this.inbox;
      const instagramInbox =
        this.$store.getters['inboxes/getInstagramInboxByInstagramId'](
          instagramId
        );

      return (
        this.inbox.channel_type === INBOX_TYPES.FB &&
        additionalAttributes.type === 'instagram_direct_message' &&
        instagramInbox
      );
    },
    replyWindowBannerMessage() {
      if (this.isAWhatsAppChannel) {
        return this.$t('CONVERSATION.TWILIO_WHATSAPP_CAN_REPLY');
      }
      if (this.isAPIInbox) {
        const { additional_attributes: additionalAttributes = {} } = this.inbox;
        if (additionalAttributes) {
          const {
            agent_reply_time_window_message: agentReplyTimeWindowMessage,
            agent_reply_time_window: agentReplyTimeWindow,
          } = additionalAttributes;
          return (
            agentReplyTimeWindowMessage ||
            this.$t('CONVERSATION.API_HOURS_WINDOW', {
              hours: agentReplyTimeWindow,
            })
          );
        }
        return '';
      }
      return this.$t('CONVERSATION.CANNOT_REPLY');
    },
    replyWindowLink() {
      if (this.isAFacebookInbox || this.isAnInstagramChannel) {
        return REPLY_POLICY.FACEBOOK;
      }
      if (this.isAWhatsAppCloudChannel) {
        return REPLY_POLICY.WHATSAPP_CLOUD;
      }
      if (this.isATiktokChannel) {
        return REPLY_POLICY.TIKTOK;
      }
      if (!this.isAPIInbox) {
        return REPLY_POLICY.TWILIO_WHATSAPP;
      }
      return '';
    },
    replyWindowLinkText() {
      if (
        this.isAWhatsAppChannel ||
        this.isAFacebookInbox ||
        this.isAnInstagramChannel
      ) {
        return this.$t('CONVERSATION.24_HOURS_WINDOW');
      }
      if (this.isATiktokChannel) {
        return this.$t('CONVERSATION.48_HOURS_WINDOW');
      }
      if (!this.isAPIInbox) {
        return this.$t('CONVERSATION.TWILIO_WHATSAPP_24_HOURS_WINDOW');
      }
      return '';
    },
    unreadMessageCount() {
      return this.currentChat.unread_count || 0;
    },
    unreadMessageLabel() {
      const count =
        this.unreadMessageCount > 9 ? '9+' : this.unreadMessageCount;
      const label =
        this.unreadMessageCount > 1
          ? 'CONVERSATION.UNREAD_MESSAGES'
          : 'CONVERSATION.UNREAD_MESSAGE';
      return `${count} ${this.$t(label)}`;
    },
    inboxSupportsReplyTo() {
      const incoming = this.inboxHasFeature(INBOX_FEATURES.REPLY_TO);
      const outgoing =
        this.inboxHasFeature(INBOX_FEATURES.REPLY_TO_OUTGOING) &&
        !this.is360DialogWhatsAppChannel;

      return { incoming, outgoing };
    },
  },

  watch: {
    currentChat(newChat, oldChat) {
      if (newChat.id === oldChat.id) {
        return;
      }
      this.fetchAllAttachmentsFromCurrentChat();
      this.fetchSuggestions();
      this.messageSentSinceOpened = false;
      this.composerOpen = false;
      this.showActivities = false;
      this.resetReplyEditorHeight();
      this.queueScrollToTop();
    },
  },

  created() {
    emitter.on(BUS_EVENTS.SCROLL_TO_MESSAGE, this.onScrollToMessage);
    // when a message is sent we set the flag to true this hides the label suggestions,
    // until the chat is changed and the flag is reset in the watch for currentChat
    emitter.on(BUS_EVENTS.MESSAGE_SENT, this.onMessageSent);
    // Freshdesk: the toolbar's Reply / Note / Forward reveals the composer.
    emitter.on('freshdesk:set-reply-mode', this.onOpenComposer);
    // Freshdesk: the toolbar's Activities button reveals the hidden activity log.
    emitter.on('freshdesk:toggle-activities', this.onToggleActivities);
  },

  mounted() {
    this.addScrollListener();
    this.fetchAllAttachmentsFromCurrentChat();
    this.fetchSuggestions();
  },

  unmounted() {
    this.removeBusListeners();
    this.removeScrollListener();
  },

  methods: {
    async fetchSuggestions() {
      // start empty, this ensures that the label suggestions are not shown
      this.labelSuggestions = [];

      if (this.isLabelSuggestionDismissed()) {
        return;
      }

      // Early exit if conversation already has labels - no need to suggest more
      const existingLabels = this.currentChat?.labels || [];
      if (existingLabels.length > 0) return;

      if (!this.captainTasksEnabled || !this.isLabelSuggestionFeatureEnabled) {
        return;
      }

      this.labelSuggestions = await this.getLabelSuggestions();

      // once the labels are fetched, we need to adjust the scroll
      // but we need to wait for the DOM to be updated
      // so we use the nextTick method
      this.$nextTick(() => {
        // this param is added to route, telling the UI to navigate to the message
        // it is triggered by the SCROLL_TO_MESSAGE method
        // see setActiveChat on ConversationView.vue for more info
        const { messageId } = this.$route.query;

        if (this.isAnEmailChannel) {
          this.queueScrollToTop();
          return;
        }

        // only trigger the scroll to bottom if the user has not scrolled
        // and there's no active messageId that is selected in view
        if (!messageId && !this.hasUserScrolled) {
          this.scrollToBottom();
        }
      });
    },
    isLabelSuggestionDismissed() {
      return LocalStorage.getFlag(
        LOCAL_STORAGE_KEYS.DISMISSED_LABEL_SUGGESTIONS,
        this.currentAccountId,
        this.currentChat.id
      );
    },
    fetchAllAttachmentsFromCurrentChat() {
      this.$store.dispatch('fetchAllAttachments', this.currentChat.id);
    },
    removeBusListeners() {
      emitter.off(BUS_EVENTS.SCROLL_TO_MESSAGE, this.onScrollToMessage);
      emitter.off(BUS_EVENTS.MESSAGE_SENT, this.onMessageSent);
      emitter.off('freshdesk:set-reply-mode', this.onOpenComposer);
      emitter.off('freshdesk:toggle-activities', this.onToggleActivities);
    },
    onToggleActivities() {
      this.showActivities = !this.showActivities;
    },
    onMessageSent() {
      this.messageSentSinceOpened = true;
      // Collapse the composer after sending, like Freshdesk.
      this.composerOpen = false;
    },
    onOpenComposer(mode) {
      this.composerOpen = true;
      this.$nextTick(() => {
        if (
          mode === REPLY_EDITOR_MODES.REPLY ||
          mode === REPLY_EDITOR_MODES.NOTE
        ) {
          // Sets the mode AND focuses the editor with the caret at the end of
          // any existing draft text (same combined handler the header's
          // Reply/Note buttons already use via the emitter).
          this.replyBoxRef?.onFreshdeskSetReplyMode?.(mode);
        }
        this.resizableEditorWrapperRef?.expandEditorFull?.();
        this.scrollToComposer();
      });
    },
    // Bottom compact-composer tabs open the full editor in the chosen mode.
    // Forward has no dedicated editor mode yet, so it opens a reply.
    startCompose(mode) {
      this.onOpenComposer(
        mode === REPLY_EDITOR_MODES.NOTE
          ? REPLY_EDITOR_MODES.NOTE
          : REPLY_EDITOR_MODES.REPLY
      );
    },
    openSendAsEmailDialog() {
      this.sendAsEmailDialogRef?.open();
    },
    // The conversation's channel is now email — open the reply composer so
    // the agent can write the message that actually goes out.
    onSwitchedToEmail() {
      this.startCompose(REPLY_EDITOR_MODES.REPLY);
    },
    onCloseComposer() {
      this.replyBoxRef?.saveDraft?.(
        this.currentChat.id,
        this.$store.getters['draftMessages/getReplyEditorMode']
      );
      this.composerOpen = false;
    },
    onScrollToMessage({ messageId = '' } = {}) {
      this.$nextTick(() => {
        const messageElement = document.getElementById('message' + messageId);
        if (messageElement) {
          this.isProgrammaticScroll = true;
          messageElement.scrollIntoView({ behavior: 'smooth' });
          this.fetchPreviousMessages();
        } else {
          this.scrollToBottom();
        }
      });
      this.makeMessagesRead();
    },
    addScrollListener() {
      this.conversationPanel = this.$el.querySelector('.conversation-panel');
      this.setScrollParams();
      this.conversationPanel.addEventListener('scroll', this.handleScroll);
      this.queueScrollToTop();
      this.isLoadingPrevious = false;
    },
    removeScrollListener() {
      this.conversationPanel.removeEventListener('scroll', this.handleScroll);
    },
    scrollToBottom() {
      this.isProgrammaticScroll = true;
      let relevantMessages = [];

      // label suggestions are not part of the messages list
      // so we need to handle them separately
      let labelSuggestions =
        this.conversationPanel.querySelector('.label-suggestion');

      // if there are unread messages, scroll to the first unread message
      if (this.unreadMessageCount > 0) {
        // capturing only the unread messages
        relevantMessages =
          this.conversationPanel.querySelectorAll('.message--unread');
      } else if (labelSuggestions) {
        // when scrolling to the bottom, the label suggestions is below the last message
        // so we scroll there if there are no unread messages
        // Unread messages always take the highest priority
        relevantMessages = [labelSuggestions];
      } else {
        // if there are no unread messages or label suggestion, scroll to the last message
        // capturing last message from the messages list
        relevantMessages = Array.from(
          this.conversationPanel.querySelectorAll('.message--read')
        ).slice(-1);
      }

      this.conversationPanel.scrollTop = calculateScrollTop(
        this.conversationPanel.scrollHeight,
        this.$el.scrollHeight,
        relevantMessages
      );
    },
    scrollToTop() {
      if (!this.conversationPanel) {
        return;
      }
      this.isProgrammaticScroll = true;
      this.conversationPanel.scrollTop = 0;
    },
    scrollToComposer() {
      if (!this.conversationPanel) {
        return;
      }
      this.isProgrammaticScroll = true;
      requestAnimationFrame(() => {
        const composer = this.$el.querySelector('[data-freshdesk-composer]');
        const top = composer?.offsetTop ?? this.conversationPanel.scrollHeight;
        this.conversationPanel.scrollTo({ top, behavior: 'smooth' });
      });
    },
    queueScrollToTop() {
      this.$nextTick(() => {
        this.scrollToTop();
        requestAnimationFrame(() => {
          this.scrollToTop();
          setTimeout(() => this.scrollToTop(), 80);
        });
      });
    },
    setScrollParams() {
      this.heightBeforeLoad = this.conversationPanel.scrollHeight;
      this.scrollTopBeforeLoad = this.conversationPanel.scrollTop;
    },

    async fetchPreviousMessages(scrollTop = 0) {
      this.setScrollParams();
      const shouldLoadMoreMessages =
        this.currentChat.dataFetched === true &&
        !this.listLoadingStatus &&
        !this.isLoadingPrevious;

      if (
        scrollTop < 100 &&
        !this.isLoadingPrevious &&
        shouldLoadMoreMessages
      ) {
        this.isLoadingPrevious = true;
        try {
          await this.$store.dispatch('fetchPreviousMessages', {
            conversationId: this.currentChat.id,
            before: this.currentChat.messages[0].id,
          });
          const heightDifference =
            this.conversationPanel.scrollHeight - this.heightBeforeLoad;
          this.conversationPanel.scrollTop =
            this.scrollTopBeforeLoad + heightDifference;
          this.setScrollParams();
        } catch (error) {
          // Ignore Error
        } finally {
          this.isLoadingPrevious = false;
        }
      }
    },

    handleScroll(e) {
      if (this.isProgrammaticScroll) {
        // Reset the flag
        this.isProgrammaticScroll = false;
        this.hasUserScrolled = false;
      } else {
        this.hasUserScrolled = true;
      }
      emitter.emit(BUS_EVENTS.ON_MESSAGE_LIST_SCROLL);
      this.fetchPreviousMessages(e.target.scrollTop);
    },

    makeMessagesRead() {
      this.$store.dispatch('markMessagesRead', { id: this.currentChat.id });
    },
    async handleMessageRetry(message) {
      if (!message) return;
      const payload = useSnakeCase(message);
      await this.$store.dispatch('sendMessageWithData', payload);
    },
    toggleReplyEditorSize() {
      this.resizableEditorWrapperRef?.toggleEditorExpand?.();
    },
    resetReplyEditorHeight() {
      this.resizableEditorWrapperRef?.resetEditorHeight?.();
    },
  },
};
</script>

<template>
  <div
    ref="messagesViewRef"
    class="flex flex-col justify-between flex-grow h-full min-w-0 m-0 bg-fd-surface"
  >
    <div ref="topBannerRef">
      <Banner
        v-if="!currentChat.can_reply"
        color-scheme="alert"
        class="mx-2 mt-2 overflow-hidden rounded-lg"
        :banner-message="replyWindowBannerMessage"
        :href-link="replyWindowLink"
        :href-link-text="replyWindowLinkText"
      />
      <Banner
        v-else-if="hasDuplicateInstagramInbox"
        color-scheme="alert"
        class="mx-2 mt-2 overflow-hidden rounded-lg"
        :banner-message="$t('CONVERSATION.OLD_INSTAGRAM_INBOX_REPLY_BANNER')"
      />
    </div>
    <MessageList
      ref="conversationPanelRef"
      class="conversation-panel flex-shrink flex-grow basis-px flex flex-col overflow-y-auto relative h-full m-0 bg-fd-surface px-[var(--conv-gutter)] pb-4 [--conv-gutter:clamp(0.75rem,1.4vw,1.25rem)]"
      :current-user-id="currentUserId"
      :first-unread-id="unReadMessages[0]?.id"
      :is-an-email-channel="isAnEmailChannel"
      :inbox-supports-reply-to="inboxSupportsReplyTo"
      :messages="getMessages"
      @retry="handleMessageRetry"
    >
      <template #beforeAll>
        <transition name="slide-up">
          <!-- Email/ticket threads start at the top (Freshdesk); chat threads
               keep the `first:mt-auto` trick that bottom-aligns messages.
               Voice tickets read like an email/ticket thread too - the call
               summary is a standalone record, not a live back-and-forth - so
               they're excluded from the bottom-anchor trick as well. -->
          <!-- eslint-disable-next-line vue/require-toggle-inside-transition -->
          <li
            v-if="shouldShowSpinner || !isAnEmailChannel"
            class="flex flex-shrink-0 flex-grow-0 items-center justify-center max-w-full mt-0 mr-0 mb-1 ml-0 relative last:mb-0"
            :class="[
              shouldShowSpinner ? 'min-h-[4rem]' : 'min-h-0',
              {
                'flex-auto first:mt-auto':
                  !isAnEmailChannel && !isVoiceCallConversation,
              },
            ]"
          >
            <Spinner v-if="shouldShowSpinner" class="text-n-brand" />
          </li>
        </transition>
      </template>
      <template #unreadBadge>
        <li
          v-show="unreadMessageCount != 0"
          class="list-none flex justify-center items-center"
        >
          <span
            class="shadow-lg rounded-full bg-n-brand text-white text-xs font-medium my-2.5 mx-auto px-2.5 py-1.5"
          >
            {{ unreadMessageLabel }}
          </span>
        </li>
      </template>
      <template #after>
        <ConversationLabelSuggestion
          v-if="shouldShowLabelSuggestions"
          :suggested-labels="labelSuggestions"
          :chat-labels="currentChat.labels"
          :conversation-id="currentChat.id"
        />
        <li
          v-show="composerOpen"
          data-freshdesk-composer
          class="list-none border-t border-n-weak bg-fd-surface"
        >
          <div
            class="sticky top-0 z-20 flex items-center justify-end bg-fd-surface px-3 pt-3"
          >
            <button
              type="button"
              class="flex items-center gap-1 rounded px-1.5 py-0.5 text-xs text-fd-muted hover:bg-n-slate-3 hover:text-fd-text"
              :title="$t('CHAT_LIST.FRESHDESK_DETAIL.CLOSE_COMPOSER')"
              @click="onCloseComposer"
            >
              <span class="i-lucide-x size-3.5" />
              {{ $t('CHAT_LIST.FRESHDESK_DETAIL.CLOSE_COMPOSER') }}
            </button>
          </div>
          <ResizableEditorWrapper
            ref="resizableEditorWrapperRef"
            :container-height="Math.max(0, containerHeight - topBannerHeight)"
          >
            <ReplyBox
              ref="replyBoxRef"
              @toggle-editor-size="toggleReplyEditorSize"
            />
          </ResizableEditorWrapper>
        </li>
        <li v-show="!composerOpen" class="list-none pl-0 pr-3 pb-2 pt-2">
          <div class="flex items-start gap-2">
            <span
              class="mt-0.5 grid size-8 shrink-0 place-content-center rounded-full bg-[#e9ddff] text-xs font-semibold text-[#6e55c9]"
            >
              {{ composerAvatarInitial }}
            </span>
            <div
              class="min-w-0 flex-1 rounded-lg border border-fd-border bg-fd-surface"
            >
              <div
                class="flex items-center gap-1 border-b border-fd-border px-2 py-1.5"
              >
                <button
                  type="button"
                  class="inline-flex h-7 items-center gap-1.5 rounded-md bg-fd-blueSoft px-2.5 text-xs font-semibold text-fd-blue"
                  @click="startCompose('REPLY')"
                >
                  <span class="i-lucide-mail size-3.5" />
                  {{ $t('CHAT_LIST.FRESHDESK_DETAIL.REPLY') }}
                </button>
                <button
                  type="button"
                  class="inline-flex h-7 items-center gap-1.5 rounded-md px-2.5 text-xs font-medium text-fd-muted hover:bg-n-slate-2 hover:text-fd-text"
                  @click="startCompose('NOTE')"
                >
                  <span class="i-lucide-file-text size-3.5" />
                  {{ $t('CHAT_LIST.FRESHDESK_DETAIL.NOTE') }}
                </button>
                <button
                  type="button"
                  class="inline-flex h-7 items-center gap-1.5 rounded-md px-2.5 text-xs font-medium text-fd-muted hover:bg-n-slate-2 hover:text-fd-text"
                  @click="startCompose('FORWARD')"
                >
                  <span class="i-lucide-forward size-3.5" />
                  {{ $t('CHAT_LIST.FRESHDESK_DETAIL.FORWARD') }}
                </button>
                <button
                  v-if="isAWebWidgetInbox"
                  type="button"
                  class="inline-flex h-7 items-center gap-1.5 rounded-md px-2.5 text-xs font-medium text-fd-muted hover:bg-n-slate-2 hover:text-fd-text"
                  @click="openSendAsEmailDialog"
                >
                  <span class="i-lucide-send-horizontal size-3.5" />
                  {{ $t('CHAT_LIST.FRESHDESK_DETAIL.SEND_EMAIL.BUTTON') }}
                </button>
              </div>
              <div
                class="flex cursor-text items-center gap-2 px-3 py-2.5"
                @click="startCompose('REPLY')"
              >
                <span class="flex-1 truncate text-sm text-fd-muted">
                  {{ $t('CHAT_LIST.FRESHDESK_DETAIL.COMPOSER_PLACEHOLDER') }}
                </span>
                <button
                  type="button"
                  class="grid size-8 shrink-0 place-content-center rounded-md bg-fd-primary text-white hover:opacity-90"
                  @click.stop="startCompose('REPLY')"
                >
                  <span class="i-lucide-send size-4" />
                </button>
              </div>
            </div>
          </div>
        </li>
      </template>
    </MessageList>
    <div class="flex relative flex-col border-t border-fd-border bg-fd-surface">
      <div
        v-if="isAnyoneTyping"
        class="absolute flex items-center w-full h-0 -top-7"
      >
        <div
          class="flex py-2 pr-4 pl-5 shadow-md rounded-full bg-white dark:bg-n-solid-3 text-n-slate-11 text-xs font-semibold my-2.5 mx-auto"
        >
          {{ typingUserNames }}
          <img
            class="w-6 ltr:ml-2 rtl:mr-2"
            src="assets/images/typing.gif"
            alt="Someone is typing"
          />
        </div>
      </div>
    </div>
    <SendAsEmailDialog
      ref="sendAsEmailDialogRef"
      :chat="currentChat"
      @switched="onSwitchedToEmail"
    />
  </div>
</template>

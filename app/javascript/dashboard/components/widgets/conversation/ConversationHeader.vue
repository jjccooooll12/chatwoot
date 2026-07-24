<script setup>
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useElementSize } from '@vueuse/core';
import BackButton from '../BackButton.vue';
import InboxName from '../InboxName.vue';
import MoreActions from './MoreActions.vue';
import ResolveAction from '../../buttons/ResolveAction.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import ConversationCallButton from './ConversationCallButton.vue';
import wootConstants from 'dashboard/constants/globals';
import { conversationListPageURL } from 'dashboard/helper/URLHelper';
import { snoozedReopenTime } from 'dashboard/helper/snoozeHelpers';
import { useInbox } from 'dashboard/composables/useInbox';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { emitter } from 'shared/helpers/mitt';
import { getLastMessage } from 'dashboard/helper/conversationHelper';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
  showBackButton: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const conversationHeader = ref(null);
const { width } = useElementSize(conversationHeader);
const { isAWebWidgetInbox } = useInbox();
const { getPlainText } = useMessageFormatter();

const currentChat = computed(() => store.getters.getSelectedChat);
const accountId = computed(() => store.getters.getCurrentAccountId);

const chatMetadata = computed(() => props.chat.meta);

const backButtonUrl = computed(() => {
  const {
    params: { inbox_id: inboxId, label, teamId, id: customViewId },
    name,
  } = route;

  const conversationTypeMap = {
    conversation_through_mentions: 'mention',
    conversation_through_participating: 'participating',
    conversation_through_unattended: 'unattended',
  };
  return conversationListPageURL({
    accountId: accountId.value,
    inboxId,
    label,
    teamId,
    conversationType: conversationTypeMap[name],
    customViewId,
  });
});

const isHMACVerified = computed(() => {
  if (!isAWebWidgetInbox.value) {
    return true;
  }
  return chatMetadata.value.hmac_verified;
});

const currentContact = computed(() =>
  store.getters['contacts/getContact'](props.chat.meta.sender.id)
);

const lastMessageInChat = computed(() => getLastMessage(props.chat));

const subject = computed(() => {
  const customAttributes =
    props.chat.custom_attributes || props.chat.customAttributes || {};
  const emailSubject = customAttributes.email?.subject;
  return getPlainText(
    emailSubject ||
      lastMessageInChat.value?.content ||
      t('CHAT_LIST.NO_CONTENT')
  );
});

const isSnoozed = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.SNOOZED
);

const snoozedDisplayText = computed(() => {
  const { snoozed_until: snoozedUntil } = currentChat.value;
  if (snoozedUntil) {
    return `${t('CONVERSATION.HEADER.SNOOZED_UNTIL')} ${snoozedReopenTime(snoozedUntil)}`;
  }
  return t('CONVERSATION.HEADER.SNOOZED_UNTIL_NEXT_REPLY');
});

const inbox = computed(() => {
  const { inbox_id: inboxId } = props.chat;
  return store.getters['inboxes/getInbox'](inboxId);
});

const hasMultipleInboxes = computed(
  () => store.getters['inboxes/getInboxes'].length > 1
);

const hasSlaPolicyId = computed(
  () => props.chat?.applied_sla?.id && !currentContact.value?.blocked
);

const copyConversationId = async () => {
  try {
    await copyTextToClipboard(String(props.chat.id));
    useAlert(t('CONVERSATION.HEADER.COPY_ID_SUCCESS'));
  } catch (error) {
    // error
  }
};

const setEditorMode = mode => {
  emitter.emit('freshdesk:set-reply-mode', mode);
};
</script>

<template>
  <div
    ref="conversationHeader"
    class="flex min-h-[100px] w-full flex-col border-b border-fd-border bg-fd-surface"
  >
    <div class="flex h-12 items-center justify-between gap-3 px-3">
      <div class="flex min-w-0 items-center gap-2">
        <BackButton
          v-if="showBackButton"
          :back-url="backButtonUrl"
          class="ltr:mr-0 rtl:ml-0"
        />
        <button
          type="button"
          class="grid size-7 place-content-center rounded-md border border-fd-border text-fd-muted hover:border-fd-primary hover:text-fd-primary"
        >
          <span class="i-lucide-star size-3.5" />
        </button>
        <button
          type="button"
          class="inline-flex h-8 items-center gap-1.5 rounded-md border border-fd-border bg-fd-surface px-3 text-sm font-medium text-fd-text hover:border-fd-primary hover:text-fd-primary"
          @click="setEditorMode(REPLY_EDITOR_MODES.REPLY)"
        >
          <span class="i-lucide-reply size-3.5" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.REPLY') }}
        </button>
        <button
          type="button"
          class="inline-flex h-8 items-center gap-1.5 rounded-md border border-fd-border bg-fd-surface px-3 text-sm font-medium text-fd-text hover:border-fd-primary hover:text-fd-primary"
          @click="setEditorMode(REPLY_EDITOR_MODES.NOTE)"
        >
          <span class="i-lucide-file-text size-3.5" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.NOTE') }}
        </button>
        <button
          type="button"
          class="hidden h-8 items-center gap-1.5 rounded-md border border-fd-border bg-fd-surface px-3 text-sm font-medium text-fd-text hover:border-fd-primary hover:text-fd-primary md:inline-flex"
          @click="setEditorMode(REPLY_EDITOR_MODES.REPLY)"
        >
          <span class="i-lucide-forward size-3.5" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.FORWARD') }}
        </button>
        <ResolveAction
          :conversation-id="currentChat.id"
          :status="currentChat.status"
        />
      </div>

      <div class="flex shrink-0 items-center gap-2">
        <button
          type="button"
          class="hidden h-8 items-center gap-1.5 rounded-md border border-fd-border bg-fd-surface px-3 text-sm font-medium text-fd-text hover:border-fd-primary hover:text-fd-primary lg:inline-flex"
        >
          <span class="i-lucide-alarm-clock size-3.5" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.ACTIVITIES') }}
        </button>
        <ConversationCallButton :inbox="inbox" :chat="currentChat" />
        <MoreActions :conversation-id="currentChat.id" />
      </div>
    </div>

    <div class="flex min-h-12 items-start justify-between gap-3 px-5 pb-4">
      <div class="flex min-w-0 items-start gap-4">
        <span
          class="mt-1 grid size-5 shrink-0 place-content-center rounded bg-fd-muted text-white"
        >
          <span class="i-lucide-check size-3.5" />
        </span>
        <div class="min-w-0">
          <div
            class="mb-1 flex min-w-0 flex-wrap items-center gap-1.5 text-xs text-fd-muted"
          >
            <button
              type="button"
              class="text-fd-primary hover:underline"
              @click="copyConversationId"
            >
              {{ `#${chat.id}` }}
            </button>
            <span v-if="hasMultipleInboxes">
              {{ t('CHAT_LIST.FRESHDESK_CARD.SEPARATOR') }}
            </span>
            <InboxName v-if="hasMultipleInboxes" :inbox="inbox" class="!mx-0" />
            <span v-if="isSnoozed">
              {{ t('CHAT_LIST.FRESHDESK_CARD.SEPARATOR') }}
            </span>
            <span v-if="isSnoozed" class="font-medium text-n-amber-10">
              {{ snoozedDisplayText }}
            </span>
            <fluent-icon
              v-if="!isHMACVerified"
              v-tooltip="$t('CONVERSATION.UNVERIFIED_SESSION')"
              size="14"
              class="text-n-amber-10"
              icon="warning"
            />
          </div>
          <h1 class="m-0 truncate text-xl font-semibold leading-7 text-fd-text">
            {{ subject }}
          </h1>
        </div>
      </div>

      <SLACardLabel
        v-if="hasSlaPolicyId"
        :chat="chat"
        show-extended-info
        :parent-width="width"
        class="mt-0.5 hidden md:flex"
      />
    </div>
  </div>
</template>

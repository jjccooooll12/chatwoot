<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import BackButton from '../BackButton.vue';
import InboxName from '../InboxName.vue';
import MoreActions from './MoreActions.vue';
import ConversationMergePanel from './ConversationMergePanel.vue';
import ResolveAction from '../../buttons/ResolveAction.vue';
import ConversationCallButton from './ConversationCallButton.vue';
import {
  conversationListPageURL,
  frontendURL,
} from 'dashboard/helper/URLHelper';
import { useInbox } from 'dashboard/composables/useInbox';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { emitter } from 'shared/helpers/mitt';
import { getLastMessage } from 'dashboard/helper/conversationHelper';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';
import { MESSAGE_TYPE } from 'shared/constants/messages';

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
const router = useRouter();
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

const lastMessageInChat = computed(() => getLastMessage(props.chat));

const subject = computed(() => {
  const additionalAttributes =
    props.chat.additional_attributes || props.chat.additionalAttributes || {};
  const emailSubject =
    additionalAttributes.mail_subject || additionalAttributes.mailSubject;
  return getPlainText(
    emailSubject ||
      lastMessageInChat.value?.content ||
      t('CHAT_LIST.NO_CONTENT')
  );
});

const hasAgentReplied = computed(() =>
  Boolean(props.chat.first_reply_created_at)
);
const lastMessageIsIncoming = computed(
  () => lastMessageInChat.value?.message_type === MESSAGE_TYPE.INCOMING
);
// Freshdesk "Customer responded": the latest message is from the customer and
// an agent had already replied earlier in the thread.
const customerResponded = computed(
  () => lastMessageIsIncoming.value && hasAgentReplied.value
);

const ticketNumber = computed(() => {
  const additionalAttributes =
    props.chat.additional_attributes || props.chat.additionalAttributes || {};
  return additionalAttributes.ticket_number || props.chat.id;
});

const inbox = computed(() => {
  const { inbox_id: inboxId } = props.chat;
  return store.getters['inboxes/getInbox'](inboxId);
});

const hasMultipleInboxes = computed(
  () => store.getters['inboxes/getInboxes'].length > 1
);

const copyConversationId = async () => {
  try {
    await copyTextToClipboard(String(ticketNumber.value));
    useAlert(t('CONVERSATION.HEADER.COPY_ID_SUCCESS'));
  } catch (error) {
    // error
  }
};

const setEditorMode = mode => {
  emitter.emit('freshdesk:set-reply-mode', mode);
};

// Activity log lines are hidden from the thread by default; this button reveals
// them. Reset the local pressed state whenever the open ticket changes so it
// stays in sync with the thread (which also re-hides activities per conversation).
const activitiesVisible = ref(false);
const toggleActivities = () => {
  activitiesVisible.value = !activitiesVisible.value;
  emitter.emit('freshdesk:toggle-activities');
};
watch(
  () => props.chat.id,
  () => {
    activitiesVisible.value = false;
  }
);

const deleteDialogRef = ref(null);
const showMergePanel = ref(false);

const onDeleteClick = () => {
  deleteDialogRef.value?.open();
};

const openMergePanel = () => {
  showMergePanel.value = true;
};

const closeMergePanel = () => {
  showMergePanel.value = false;
};

const onTicketMerged = async mergedConversation => {
  const mergeActivity = mergedConversation?.messages?.[0];
  if (mergeActivity) {
    store.dispatch('addMessage', mergeActivity);
  }
  store.dispatch('updateConversation', mergedConversation);
  closeMergePanel();
  useAlert(t('CONVERSATION.MERGE_SUCCESS'));

  if (
    mergedConversation?.id &&
    String(mergedConversation.id) !== String(props.chat.id)
  ) {
    await router.push(
      frontendURL(
        `accounts/${accountId.value}/conversations/${mergedConversation.id}`
      )
    );
    return;
  }

  await store.dispatch('getConversation', props.chat.id);
};

// Deleting the ticket also soft-deletes its inbound emails in Outlook
// (handled server-side in Conversations::DeleteService).
const confirmDeleteConversation = async () => {
  const number = ticketNumber.value;
  try {
    await store.dispatch('deleteConversation', props.chat.id);
    deleteDialogRef.value?.close();
    useAlert(
      t('CONVERSATION.SUCCESS_DELETE_TICKET', { conversationId: number })
    );
    router.push(backButtonUrl.value);
  } catch (error) {
    useAlert(t('CONVERSATION.FAIL_DELETE_CONVERSATION'));
  }
};
</script>

<template>
  <div
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
          class="grid size-8 place-content-center rounded-md border border-n-slate-7 bg-fd-surface text-fd-muted shadow-sm hover:border-n-slate-8 hover:bg-n-slate-2 hover:text-fd-text"
        >
          <span class="i-lucide-star size-3.5" />
        </button>
        <button
          type="button"
          class="inline-flex h-8 items-center gap-1.5 rounded-md border border-n-slate-7 bg-fd-surface px-3 text-sm font-medium text-fd-text shadow-sm hover:border-n-slate-8 hover:bg-n-slate-2"
          @click="setEditorMode(REPLY_EDITOR_MODES.REPLY)"
        >
          <span class="i-lucide-reply size-3.5" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.REPLY') }}
        </button>
        <button
          type="button"
          class="inline-flex h-8 items-center gap-1.5 rounded-md border border-n-slate-7 bg-fd-surface px-3 text-sm font-medium text-fd-text shadow-sm hover:border-n-slate-8 hover:bg-n-slate-2"
          @click="setEditorMode(REPLY_EDITOR_MODES.NOTE)"
        >
          <span class="i-lucide-file-text size-3.5" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.NOTE') }}
        </button>
        <button
          type="button"
          class="hidden h-8 items-center gap-1.5 rounded-md border border-n-slate-7 bg-fd-surface px-3 text-sm font-medium text-fd-text shadow-sm hover:border-n-slate-8 hover:bg-n-slate-2 md:inline-flex"
          @click="setEditorMode(REPLY_EDITOR_MODES.REPLY)"
        >
          <span class="i-lucide-forward size-3.5" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.FORWARD') }}
        </button>
        <button
          type="button"
          class="inline-flex h-8 items-center gap-1.5 rounded-md border border-n-slate-7 bg-fd-surface px-3 text-sm font-medium text-fd-text shadow-sm hover:border-n-slate-8 hover:bg-n-slate-2"
          @click="openMergePanel"
        >
          <span class="i-lucide-git-merge size-3.5" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.BUTTON') }}
        </button>
        <ResolveAction
          :conversation-id="currentChat.id"
          :status="currentChat.status"
        />
      </div>

      <div class="flex shrink-0 items-center gap-2">
        <button
          type="button"
          class="hidden h-8 items-center gap-1.5 rounded-md border bg-fd-surface px-3 text-sm font-medium shadow-sm hover:bg-n-slate-2 lg:inline-flex"
          :class="
            activitiesVisible
              ? 'border-fd-primary text-fd-primary'
              : 'border-n-slate-7 text-fd-text hover:border-n-slate-8'
          "
          @click="toggleActivities"
        >
          <span class="i-lucide-alarm-clock size-3.5" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.ACTIVITIES') }}
        </button>
        <ConversationCallButton :inbox="inbox" :chat="currentChat" />
        <button
          type="button"
          class="grid size-8 place-content-center rounded-md border border-n-slate-7 bg-fd-surface text-fd-muted shadow-sm hover:border-n-ruby-9 hover:bg-n-ruby-2 hover:text-n-ruby-11"
          :title="$t('CONVERSATION.DELETE_CONVERSATION.CONFIRM')"
          @click="onDeleteClick"
        >
          <span class="i-lucide-trash-2 size-4" />
        </button>
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
              {{ `#${ticketNumber}` }}
            </button>
            <span v-if="hasMultipleInboxes">
              {{ t('CHAT_LIST.FRESHDESK_CARD.SEPARATOR') }}
            </span>
            <InboxName v-if="hasMultipleInboxes" :inbox="inbox" class="!mx-0" />
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
          <span
            v-if="customerResponded"
            class="mt-1 inline-flex w-fit rounded bg-fd-blueSoft px-1.5 py-0.5 text-xxs font-medium leading-4 text-fd-blue"
          >
            {{ t('CHAT_LIST.FRESHDESK_CARD.STATUS.CUSTOMER_RESPONDED') }}
          </span>
        </div>
      </div>
    </div>
    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="
        $t('CONVERSATION.DELETE_CONVERSATION.TITLE', {
          conversationId: ticketNumber,
        })
      "
      :description="$t('CONVERSATION.DELETE_CONVERSATION.DESCRIPTION')"
      :confirm-button-label="$t('CONVERSATION.DELETE_CONVERSATION.CONFIRM')"
      @confirm="confirmDeleteConversation"
    />
    <ConversationMergePanel
      v-if="showMergePanel"
      :chat="currentChat"
      @close="closeMergePanel"
      @merged="onTicketMerged"
    />
  </div>
</template>

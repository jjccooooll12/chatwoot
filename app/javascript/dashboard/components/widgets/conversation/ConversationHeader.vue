<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import MoreActions from './MoreActions.vue';
import FreshdeskTopBarActions from 'dashboard/components/FreshdeskTopBarActions.vue';
import ConversationMergePanel from './ConversationMergePanel.vue';
import ConversationCallButton from './ConversationCallButton.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import {
  conversationListPageURL,
  frontendURL,
} from 'dashboard/helper/URLHelper';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { emitter } from 'shared/helpers/mitt';
import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const currentChat = computed(() => store.getters.getSelectedChat);
const accountId = computed(() => store.getters.getCurrentAccountId);

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

const ticketNumber = computed(() => {
  const additionalAttributes =
    props.chat.additional_attributes || props.chat.additionalAttributes || {};
  return additionalAttributes.ticket_number || props.chat.id;
});

const inbox = computed(() => {
  const { inbox_id: inboxId } = props.chat;
  return store.getters['inboxes/getInbox'](inboxId);
});

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
const onDeleteClick = () => {
  deleteDialogRef.value?.open();
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

const showMergePanel = ref(false);

const openMergePanel = () => {
  showMergePanel.value = true;
};

const closeMergePanel = () => {
  showMergePanel.value = false;
};

const onTicketMerged = async (
  mergedConversation,
  { secondaryConversation } = {}
) => {
  const mergeActivity = mergedConversation?.messages?.[0];
  if (mergeActivity) {
    store.dispatch('addMessage', mergeActivity);
  }
  store.dispatch('updateConversation', mergedConversation);

  // The merge response only returns the primary (surviving) conversation, but
  // the backend has already resolved the secondary one — patch it locally too
  // so its row shows Closed immediately, without the user refreshing the page.
  if (secondaryConversation?.id) {
    store.dispatch('updateConversation', {
      id: secondaryConversation.id,
      status: wootConstants.STATUS_TYPE.RESOLVED,
      updated_at: Date.now() / 1000,
    });
  }

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
</script>

<template>
  <div class="flex w-full flex-col bg-fd-surface">
    <div
      class="flex h-[3.25rem] items-center justify-between gap-3 border-b border-fd-border bg-[#f7f3ff] px-3"
    >
      <div
        class="flex min-w-0 items-center gap-1.5 text-xs font-medium text-fd-muted"
      >
        <span class="i-lucide-asterisk size-3 text-fd-primary" />
        <button
          type="button"
          class="truncate text-fd-primary hover:underline"
          @click="router.push(backButtonUrl)"
        >
          {{ t('CHAT_LIST.FRESHDESK_CARD.ALL_TICKETS') }}
        </button>
        <span class="i-lucide-chevron-right size-3 text-fd-muted" />
        <button
          type="button"
          class="truncate text-fd-text hover:text-fd-primary"
          @click="copyConversationId"
        >
          {{ ticketNumber }}
        </button>
      </div>

      <!-- The Properties/Contact-info panels render BELOW this row (inside
           the message-thread flex row), not beside it, so they never
           constrain this header's width the way FreshdeskStatusPanel does
           on the ticket list. Reserve that same 240px (w-60) explicitly so
           New/Search land at the identical x-position on both pages. -->
      <FreshdeskTopBarActions class="mr-60" />
    </div>

    <div
      class="flex h-11 items-center justify-between gap-3 bg-fd-surface px-3"
    >
      <div class="flex min-w-0 items-center gap-1.5">
        <button
          type="button"
          class="inline-flex h-7 items-center gap-1.5 rounded-md border border-fd-border bg-fd-surface px-2.5 text-xs font-semibold text-fd-text shadow-sm hover:bg-n-slate-2"
          @click="setEditorMode(REPLY_EDITOR_MODES.REPLY)"
        >
          <span class="i-lucide-reply size-3.5 text-fd-muted" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.REPLY') }}
        </button>
        <button
          type="button"
          class="inline-flex h-7 items-center gap-1.5 rounded-md border border-fd-border bg-fd-surface px-2.5 text-xs font-semibold text-fd-text shadow-sm hover:bg-n-slate-2"
          @click="setEditorMode(REPLY_EDITOR_MODES.NOTE)"
        >
          <span class="i-lucide-file-text size-3.5 text-fd-muted" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.NOTE') }}
        </button>
        <button
          type="button"
          class="hidden h-7 items-center gap-1.5 rounded-md border border-fd-border bg-fd-surface px-2.5 text-xs font-semibold text-fd-text shadow-sm hover:bg-n-slate-2 md:inline-flex"
          @click="setEditorMode(REPLY_EDITOR_MODES.REPLY)"
        >
          <span class="i-lucide-forward size-3.5 text-fd-muted" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.FORWARD') }}
        </button>
        <button
          type="button"
          class="hidden h-7 items-center gap-1.5 rounded-md border border-fd-border bg-fd-surface px-2.5 text-xs font-semibold text-fd-text shadow-sm hover:bg-n-slate-2 xl:inline-flex"
          @click="openMergePanel"
        >
          <span class="i-lucide-git-merge size-3.5 text-fd-muted" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.BUTTON') }}
        </button>
        <MoreActions class="freshdesk-toolbar-more" />
      </div>

      <div class="flex shrink-0 items-center gap-1.5">
        <button
          type="button"
          class="hidden h-7 items-center gap-1.5 rounded-md border bg-fd-surface px-2.5 text-xs font-semibold shadow-sm hover:bg-n-slate-2 lg:inline-flex"
          :class="
            activitiesVisible
              ? 'border-fd-primary text-fd-primary'
              : 'border-fd-border text-fd-text'
          "
          @click="toggleActivities"
        >
          <span class="i-lucide-alarm-clock size-3.5 text-fd-muted" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.ACTIVITIES') }}
        </button>
        <ConversationCallButton :inbox="inbox" :chat="currentChat" />
        <button
          type="button"
          class="grid size-7 place-content-center rounded-md border border-fd-border bg-fd-surface text-fd-muted shadow-sm hover:bg-n-slate-2 hover:text-fd-text"
        >
          <span class="i-lucide-chevron-left size-3.5" />
        </button>
        <button
          type="button"
          class="grid size-7 place-content-center rounded-md border border-fd-border bg-fd-surface text-fd-muted shadow-sm hover:border-n-ruby-9 hover:bg-n-ruby-2 hover:text-n-ruby-11"
          :title="$t('CONVERSATION.DELETE_CONVERSATION.CONFIRM')"
          @click="onDeleteClick"
        >
          <span class="i-lucide-trash-2 size-3.5" />
        </button>
        <button
          type="button"
          class="grid size-7 place-content-center rounded-md border border-fd-border bg-fd-surface text-fd-muted shadow-sm hover:bg-n-slate-2 hover:text-fd-text"
        >
          <span class="i-lucide-chevron-right size-3.5" />
        </button>
        <button
          type="button"
          class="grid size-7 place-content-center rounded-md border border-fd-border bg-fd-surface text-fd-muted shadow-sm hover:bg-n-slate-2 hover:text-fd-text"
        >
          <span class="i-lucide-panel-right-close size-3.5" />
        </button>
      </div>
    </div>

    <ConversationMergePanel
      v-if="showMergePanel"
      :chat="currentChat"
      @close="closeMergePanel"
      @merged="onTicketMerged"
    />
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
  </div>
</template>

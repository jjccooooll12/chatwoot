<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { getTicketNumber } from 'dashboard/helper/conversationHelper';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { DuplicateContactException } from 'shared/helpers/CustomErrors';
import ContactAPI from 'dashboard/api/contacts';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { dateFormat } from 'shared/helpers/timeHelper';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

const props = defineProps({
  chat: { type: Object, required: true },
  // Rendered inside FreshdeskMobileSheet on phones instead of as a column.
  inSheet: { type: Boolean, default: false },
});

const { t } = useI18n();
const store = useStore();
const route = useRoute();

const accountId = computed(() => route.params.accountId);
const contact = computed(() => props.chat?.meta?.sender || {});
const contactId = computed(() => contact.value?.id);
const contactGetter = useMapGetter('contacts/getContact');
const contactEmail = computed(
  () => contactGetter.value(contactId.value)?.email || contact.value.email
);
const isAddingEmail = ref(false);
const isSavingEmail = ref(false);
const emailInput = ref(null);
const email = ref('');
const emailError = ref('');
const duplicateContact = ref(null);
const mergeDialog = ref(null);
const mergeError = ref('');
const isMerging = ref(false);

const startAddingEmail = async () => {
  email.value = '';
  emailError.value = '';
  isAddingEmail.value = true;
  await nextTick();
  emailInput.value?.focus();
};
const cancelAddingEmail = () => {
  isAddingEmail.value = false;
  emailError.value = '';
};
const closeMergeDialog = () => {
  duplicateContact.value = null;
  mergeError.value = '';
};
const saveEmail = async () => {
  if (isSavingEmail.value || !contactId.value) return;
  isSavingEmail.value = true;
  emailError.value = '';
  try {
    await store.dispatch('contacts/update', {
      id: contactId.value,
      email: email.value.trim(),
    });
    cancelAddingEmail();
  } catch (error) {
    if (error instanceof DuplicateContactException) {
      try {
        const address = email.value.trim();
        let page = 1;
        let hasMore = false;
        do {
          const {
            data: { payload, meta },
          } = await ContactAPI.search(address, page);
          duplicateContact.value = payload.find(
            item =>
              item.id !== Number(contactId.value) &&
              item.email?.toLowerCase() === address.toLowerCase()
          );
          hasMore = meta.has_more;
          page += 1;
        } while (!duplicateContact.value && hasMore);
        if (duplicateContact.value) {
          mergeDialog.value?.open();
        } else {
          emailError.value = t(
            'CHAT_LIST.FRESHDESK_DETAIL.MERGE_EMAIL.LOOKUP_ERROR'
          );
        }
      } catch {
        emailError.value = t(
          'CHAT_LIST.FRESHDESK_DETAIL.MERGE_EMAIL.LOOKUP_ERROR'
        );
      }
    } else {
      emailError.value = error.message || t('CONTACT_FORM.ERROR_MESSAGE');
    }
  } finally {
    isSavingEmail.value = false;
  }
};

const confirmMerge = async () => {
  if (isMerging.value || !duplicateContact.value || !contactId.value) return;
  isMerging.value = true;
  mergeError.value = '';
  try {
    const mergedContact = await store.dispatch('contacts/merge', {
      childId: contactId.value,
      parentId: duplicateContact.value.id,
    });
    await store.dispatch('updateConversationContact', {
      conversationId: props.chat.id,
      ...mergedContact,
    });
    await store.dispatch('getConversation', props.chat.id);
    mergeDialog.value?.close();
    cancelAddingEmail();
  } catch {
    mergeError.value = t('CHAT_LIST.FRESHDESK_DETAIL.MERGE_EMAIL.ERROR');
  } finally {
    isMerging.value = false;
  }
};

const timeline = ref([]);
const currentPage = ref(0);
const hasMoreConversations = ref(false);
const isLoadingTimeline = ref(false);
const timelineError = ref('');
let timelineRequestId = 0;
// The timeline is fetched in pages, while the main conversations store receives
// live ticket updates. Overlay those changes without refetching the timeline.
const liveConversationGetter = useMapGetter('getConversationById');
const recentConversations = computed(() =>
  timeline.value.map(conversation => {
    const live = liveConversationGetter.value(conversation.id);
    return live ? { ...conversation, ...live } : conversation;
  })
);

const contactUrl = computed(() =>
  frontendURL(`accounts/${accountId.value}/contacts/${contactId.value}`)
);
const conversationUrl = id =>
  frontendURL(`accounts/${accountId.value}/conversations/${id}`);

const channelIconFor = conversation => {
  const inbox = store.getters['inboxes/getInbox'](conversation.inbox_id);
  const channelType = inbox?.channel_type || inbox?.channelType;
  const isWhatsApp =
    channelType === INBOX_TYPES.WHATSAPP ||
    (channelType === INBOX_TYPES.TWILIO && inbox?.medium === 'whatsapp');
  if (channelType === INBOX_TYPES.WEB) return 'i-lucide-message-circle';
  if (isWhatsApp) return 'i-woot-whatsapp';
  return 'i-lucide-mail';
};
const subjectOf = conversation => {
  const attrs = conversation.additional_attributes || {};
  return (
    attrs.mail_subject ||
    conversation.messages?.[0]?.content ||
    t('CHAT_LIST.NO_CONTENT')
  );
};
const ticketNumberOf = conversation => getTicketNumber(conversation);
const statusLabelMap = computed(() => ({
  open: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open.TEXT'),
  resolved: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.resolved.TEXT'),
  pending: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.pending.TEXT'),
  snoozed: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.snoozed.TEXT'),
}));
const statusLabel = conversation =>
  statusLabelMap.value[conversation.status] || conversation.status;
const timeLabel = conversation =>
  conversation.created_at
    ? dateFormat(conversation.created_at, 'd MMM yyyy, h:mm a')
    : '';

const fetchConversations = async (loadMore = false) => {
  const requestedContactId = contactId.value;
  if (!requestedContactId || isLoadingTimeline.value) return;
  const requestId = ++timelineRequestId;
  const page = loadMore ? currentPage.value + 1 : 1;
  if (!loadMore) {
    timeline.value = [];
    currentPage.value = 0;
    hasMoreConversations.value = false;
  }
  isLoadingTimeline.value = true;
  timelineError.value = '';
  try {
    const { data } = await ContactAPI.getConversations(requestedContactId, {
      page,
    });
    if (requestId !== timelineRequestId) return;
    timeline.value = loadMore
      ? [...timeline.value, ...data.payload]
      : data.payload;
    currentPage.value = page;
    hasMoreConversations.value = data.meta.has_more;
  } catch {
    if (requestId === timelineRequestId) {
      timelineError.value = t('CHAT_LIST.FRESHDESK_DETAIL.TIMELINE_ERROR');
    }
  } finally {
    if (requestId === timelineRequestId) {
      isLoadingTimeline.value = false;
    }
  }
};
onMounted(() => fetchConversations());
watch(contactId, () => {
  cancelAddingEmail();
  mergeDialog.value?.close();
  isLoadingTimeline.value = false;
  timelineRequestId += 1;
  fetchConversations();
});
</script>

<template>
  <aside
    class="bg-fd-surface"
    :class="
      inSheet
        ? 'block border-t border-fd-border'
        : 'hidden w-[276px] shrink-0 overflow-y-auto border-l border-fd-border xl:block'
    "
  >
    <div class="border-b border-fd-border px-3 py-4">
      <div class="mb-3 flex items-center justify-between">
        <span
          class="text-xxs font-semibold uppercase tracking-wide text-fd-muted"
        >
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.CONTACT_INFO') }}
        </span>
      </div>
      <div class="flex items-center gap-2">
        <Avatar :name="contact.name" :src="contact.thumbnail" :size="36" />
        <div class="min-w-0">
          <p class="m-0 truncate text-sm font-semibold text-fd-text">
            {{ contact.name }}
          </p>
          <p
            v-if="contact.phone_number"
            class="m-0 mt-1.5 select-text truncate text-xs text-fd-muted"
          >
            {{ contact.phone_number }}
          </p>
          <p
            v-if="contactEmail"
            class="m-0 mt-1.5 select-text truncate text-xs text-fd-primary"
            :title="contactEmail"
          >
            {{ contactEmail }}
          </p>
        </div>
      </div>
      <div v-if="contactId && !contactEmail" class="mt-3">
        <form
          v-if="isAddingEmail"
          class="flex flex-col gap-2"
          @submit.prevent="saveEmail"
        >
          <label class="text-xs font-medium text-fd-text">
            {{ t('CONTACT_FORM.FORM.EMAIL_ADDRESS.LABEL') }}
            <input
              ref="emailInput"
              v-model="email"
              type="email"
              required
              :placeholder="t('CONTACT_FORM.FORM.EMAIL_ADDRESS.PLACEHOLDER')"
              class="mt-1 block h-8 w-full rounded-md border border-fd-border bg-fd-surface px-2 text-xs text-fd-text outline-none focus:border-fd-primary"
              @input="emailError = ''"
            />
          </label>
          <p v-if="emailError" role="alert" class="m-0 text-xs text-red-600">
            {{ emailError }}
          </p>
          <div class="flex items-center gap-3">
            <button
              type="submit"
              :disabled="isSavingEmail"
              class="text-xs font-medium text-fd-primary disabled:opacity-50"
            >
              {{ t('CHAT_LIST.FRESHDESK_DETAIL.SAVE_EMAIL') }}
            </button>
            <button
              type="button"
              :disabled="isSavingEmail"
              class="text-xs text-fd-muted disabled:opacity-50"
              @click="cancelAddingEmail"
            >
              {{ t('CHAT_LIST.FRESHDESK_DETAIL.CANCEL_EMAIL') }}
            </button>
          </div>
        </form>
        <button
          v-else
          type="button"
          class="inline-flex items-center gap-1 text-xs font-medium text-fd-primary hover:underline"
          @click="startAddingEmail"
        >
          <Icon icon="i-lucide-plus" class="size-3" />
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.ADD_EMAIL') }}
        </button>
      </div>
      <a
        v-if="contactId"
        :href="contactUrl"
        class="mt-3 inline-flex items-center gap-1 text-xs font-medium text-fd-primary hover:underline"
      >
        <Icon icon="i-lucide-external-link" class="size-3" />
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.VIEW_MORE_INFO') }}
      </a>
    </div>

    <div class="px-3 py-4">
      <p class="mb-3 text-xs font-semibold text-fd-text">
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.RECENT_TIMELINE') }}
      </p>
      <p
        v-if="isLoadingTimeline && !recentConversations.length"
        class="text-xs text-fd-muted"
      >
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.TIMELINE_LOADING') }}
      </p>
      <p
        v-else-if="!recentConversations.length && !timelineError"
        class="text-xs text-fd-muted"
      >
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.NO_TIMELINE') }}
      </p>
      <ul
        v-else-if="recentConversations.length"
        class="m-0 flex list-none flex-col gap-4 p-0"
      >
        <li
          v-for="conversation in recentConversations"
          :key="conversation.id"
          class="flex gap-2"
        >
          <Icon
            :icon="channelIconFor(conversation)"
            class="mt-0.5 size-3.5 shrink-0 text-fd-muted"
          />
          <div class="min-w-0 flex-1">
            <a
              :href="conversationUrl(conversation.id)"
              class="m-0 line-clamp-2 text-xs font-medium leading-4 text-fd-text hover:text-fd-primary"
            >
              {{ subjectOf(conversation) }}
            </a>
            <p class="m-0 select-text text-xs font-medium text-fd-primary">
              {{ `#${ticketNumberOf(conversation)}` }}
            </p>
            <p class="m-0 mt-0.5 select-text text-xs text-fd-muted">
              {{ timeLabel(conversation) }}
            </p>
            <p class="m-0 select-text text-xs text-fd-muted">
              {{
                `${t('CHAT_LIST.FRESHDESK_DETAIL.STATUS_LINE')}: ${statusLabel(
                  conversation
                )}`
              }}
            </p>
          </div>
        </li>
      </ul>
      <p v-if="timelineError" role="alert" class="mt-3 text-xs text-red-600">
        {{ timelineError }}
      </p>
      <button
        v-if="timelineError && !recentConversations.length"
        type="button"
        class="mt-2 text-xs font-medium text-fd-primary hover:underline"
        @click="fetchConversations()"
      >
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.TIMELINE_RETRY') }}
      </button>
      <button
        v-if="hasMoreConversations"
        type="button"
        :disabled="isLoadingTimeline"
        class="mt-4 text-xs font-medium text-fd-primary hover:underline disabled:opacity-50"
        @click="fetchConversations(true)"
      >
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.LOAD_MORE_TICKETS') }}
      </button>
    </div>
  </aside>
  <Dialog
    ref="mergeDialog"
    type="alert"
    width="md"
    :title="t('CHAT_LIST.FRESHDESK_DETAIL.MERGE_EMAIL.TITLE')"
    :description="t('CHAT_LIST.FRESHDESK_DETAIL.MERGE_EMAIL.DESCRIPTION')"
    :confirm-button-label="t('CHAT_LIST.FRESHDESK_DETAIL.MERGE_EMAIL.CONFIRM')"
    :is-loading="isMerging"
    @confirm="confirmMerge"
    @close="closeMergeDialog"
  >
    <div
      v-if="duplicateContact"
      class="flex flex-col gap-3 text-sm text-fd-text"
    >
      <div class="rounded-lg border border-fd-border p-3">
        <p class="m-0 text-xs font-semibold text-fd-muted">
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.MERGE_EMAIL.CURRENT') }}
        </p>
        <p class="m-0 mt-1 font-medium">
          {{ contact.name }} (#{{ contact.id }})
        </p>
        <p v-if="contact.phone_number" class="m-0 text-xs text-fd-muted">
          {{ contact.phone_number }}
        </p>
      </div>
      <div class="rounded-lg border border-fd-border p-3">
        <p class="m-0 text-xs font-semibold text-fd-muted">
          {{ t('CHAT_LIST.FRESHDESK_DETAIL.MERGE_EMAIL.EXISTING') }}
        </p>
        <p class="m-0 mt-1 font-medium">
          {{ duplicateContact.name }} (#{{ duplicateContact.id }})
        </p>
        <p class="m-0 text-xs text-fd-muted">{{ duplicateContact.email }}</p>
        <p
          v-if="duplicateContact.phone_number"
          class="m-0 text-xs text-fd-muted"
        >
          {{ duplicateContact.phone_number }}
        </p>
      </div>
      <p class="m-0 text-xs text-fd-muted">
        {{ t('CHAT_LIST.FRESHDESK_DETAIL.MERGE_EMAIL.DETAILS') }}
      </p>
      <p v-if="mergeError" role="alert" class="m-0 text-xs text-red-600">
        {{ mergeError }}
      </p>
    </div>
  </Dialog>
</template>

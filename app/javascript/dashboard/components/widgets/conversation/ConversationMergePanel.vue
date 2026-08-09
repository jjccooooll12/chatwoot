<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { getTicketNumber } from 'dashboard/helper/conversationHelper';
import { useI18n } from 'vue-i18n';
import { frontendURL } from 'dashboard/helper/URLHelper';
import ConversationApi from 'dashboard/api/inbox/conversation';
import { dateFormat } from 'shared/helpers/timeHelper';
import { shortenAgentName } from 'shared/helpers/agentNameHelper';

const props = defineProps({
  chat: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close', 'merged']);

const { t } = useI18n();
const TEXT = {
  ticketsToMerge: 'Tickets to merge',
  selectedCount: count => `${count} selected`,
};

const candidates = ref([]);
const selectedConversationIds = ref([]);
const primaryConversationId = ref(props.chat.id);
const searchQuery = ref('');
const isLoading = ref(false);
const isMerging = ref(false);
const error = ref('');
const searchMode = ref(false);

const hasSelectedTickets = computed(
  () => selectedConversationIds.value.length > 0
);

const isSelectedConversation = conversationId =>
  selectedConversationIds.value.some(
    id => String(id) === String(conversationId)
  );

const selectedConversations = computed(() =>
  selectedConversationIds.value
    .map(conversationId =>
      candidates.value.find(
        conversation => String(conversation.id) === String(conversationId)
      )
    )
    .filter(Boolean)
);

const mergeConversations = computed(() => [
  props.chat,
  ...selectedConversations.value,
]);

const primaryConversation = computed(() =>
  mergeConversations.value.find(
    conversation =>
      String(conversation.id) === String(primaryConversationId.value)
  )
);

const secondaryConversations = computed(() =>
  mergeConversations.value.filter(
    conversation =>
      String(conversation.id) !== String(primaryConversationId.value)
  )
);

const secondaryConversationIds = computed(() =>
  secondaryConversations.value.map(conversation => conversation.id)
);

const ticketNumberOf = conversation => getTicketNumber(conversation);

const subjectOf = conversation => {
  const attrs = conversation.additional_attributes || {};
  return (
    attrs.mail_subject ||
    conversation.messages?.[0]?.content ||
    t('CHAT_LIST.NO_CONTENT')
  );
};

const assigneeOf = conversation =>
  conversation.meta?.assignee?.name
    ? shortenAgentName(conversation.meta.assignee.name)
    : t('CHAT_LIST.FRESHDESK_CARD.UNASSIGNED');

const statusLabelMap = computed(() => ({
  open: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open.TEXT'),
  resolved: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.resolved.TEXT'),
  pending: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.pending.TEXT'),
  snoozed: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.snoozed.TEXT'),
}));

const statusOf = conversation =>
  statusLabelMap.value[conversation.status] || conversation.status;

const timeOf = conversation =>
  conversation.last_activity_at
    ? dateFormat(conversation.last_activity_at, 'd MMM yyyy, h:mm a')
    : '';

const conversationUrl = conversation =>
  frontendURL(
    `accounts/${props.chat.account_id}/conversations/${conversation.id}`
  );

const fetchCandidates = async (q = '') => {
  isLoading.value = true;
  error.value = '';
  selectedConversationIds.value = [];
  primaryConversationId.value = props.chat.id;
  try {
    const response = await ConversationApi.getMergeCandidates({
      conversationId: props.chat.id,
      q,
    });
    candidates.value = response.data?.payload || [];
  } catch (e) {
    error.value = t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.LOAD_ERROR');
    candidates.value = [];
  } finally {
    isLoading.value = false;
  }
};

const isPrimaryConversation = conversationId =>
  String(primaryConversationId.value) === String(conversationId);

const toggleConversation = conversationId => {
  if (isSelectedConversation(conversationId)) {
    selectedConversationIds.value = selectedConversationIds.value.filter(
      id => String(id) !== String(conversationId)
    );
    if (isPrimaryConversation(conversationId)) {
      primaryConversationId.value = props.chat.id;
    }
    return;
  }

  selectedConversationIds.value = [
    ...selectedConversationIds.value,
    conversationId,
  ];
};

const setCandidateAsPrimary = conversationId => {
  if (!isSelectedConversation(conversationId)) {
    selectedConversationIds.value = [
      ...selectedConversationIds.value,
      conversationId,
    ];
  }
  primaryConversationId.value = conversationId;
};

const searchTicket = () => {
  const q = searchQuery.value.trim();
  searchMode.value = Boolean(q);
  fetchCandidates(q);
};

const clearSearch = () => {
  searchQuery.value = '';
  searchMode.value = false;
  fetchCandidates();
};

const mergeTicket = async () => {
  if (
    !hasSelectedTickets.value ||
    !primaryConversation.value ||
    !secondaryConversationIds.value.length ||
    isMerging.value
  )
    return;

  isMerging.value = true;
  error.value = '';
  try {
    const response = await ConversationApi.merge({
      conversationId: primaryConversation.value.id,
      secondaryConversationIds: secondaryConversationIds.value,
    });
    emit('merged', response.data, {
      primaryConversation: primaryConversation.value,
      secondaryConversations: secondaryConversations.value,
    });
  } catch (e) {
    error.value =
      e.response?.data?.error || t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.ERROR');
  } finally {
    isMerging.value = false;
  }
};

onMounted(() => fetchCandidates());

watch(
  () => props.chat.id,
  () => {
    searchQuery.value = '';
    searchMode.value = false;
    primaryConversationId.value = props.chat.id;
    fetchCandidates();
  }
);
</script>

<template>
  <Teleport to="body">
    <div class="fixed inset-0 z-50 flex justify-end bg-black/20">
      <button
        type="button"
        class="absolute inset-0 cursor-default"
        :aria-label="t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.CLOSE')"
        @click="emit('close')"
      />
      <aside
        class="relative flex h-full w-[440px] max-w-[calc(100vw-1rem)] flex-col bg-fd-surface shadow-2xl"
      >
        <header
          class="flex min-h-16 items-start justify-between gap-3 border-b border-fd-border px-5 py-4"
        >
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <span class="i-lucide-git-merge size-4 text-fd-muted" />
              <h2 class="m-0 text-lg font-semibold text-fd-text">
                {{ t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.TITLE') }}
              </h2>
            </div>
            <p class="m-0 mt-1 text-xs leading-5 text-fd-muted">
              {{
                t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.DESCRIPTION', {
                  count: selectedConversationIds.length,
                })
              }}
            </p>
          </div>
          <button
            type="button"
            class="grid size-8 shrink-0 place-content-center rounded-md text-fd-muted hover:bg-n-slate-2 hover:text-fd-text"
            :title="t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.CLOSE')"
            @click="emit('close')"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </header>

        <div class="flex-1 overflow-y-auto px-5 py-4">
          <form class="flex gap-2" @submit.prevent="searchTicket">
            <label class="relative min-w-0 flex-1">
              <span
                class="pointer-events-none absolute left-0 top-0 grid h-9 w-9 place-content-center text-fd-muted"
              >
                <span class="i-lucide-search size-3.5" />
              </span>
              <input
                v-model="searchQuery"
                type="text"
                class="!h-9 w-full rounded-md border border-fd-border bg-fd-surface !pl-9 !pr-3 text-sm !leading-9 text-fd-text outline-none focus:border-fd-primary"
                :placeholder="
                  t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.SEARCH_PLACEHOLDER')
                "
              />
            </label>
            <button
              type="submit"
              class="inline-flex h-9 items-center rounded-md bg-fd-primary px-3 text-sm font-medium text-white hover:opacity-90"
            >
              {{ t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.SEARCH') }}
            </button>
          </form>

          <button
            v-if="searchMode"
            type="button"
            class="mt-2 text-xs font-medium text-fd-primary hover:underline"
            @click="clearSearch"
          >
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.BACK_TO_MATCHES') }}
          </button>

          <div
            v-if="error"
            class="mt-3 rounded-md bg-n-ruby-3 p-3 text-sm text-n-ruby-11"
          >
            {{ error }}
          </div>

          <section class="mt-5">
            <div class="mb-2 flex items-center justify-between gap-3">
              <p class="m-0 text-xs font-semibold uppercase text-fd-muted">
                {{
                  searchMode
                    ? t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.SEARCH_RESULTS')
                    : TEXT.ticketsToMerge
                }}
              </p>
              <span class="text-xs font-medium text-fd-muted">
                {{ TEXT.selectedCount(selectedConversationIds.length) }}
              </span>
            </div>
            <div
              v-if="isLoading"
              class="rounded-md border border-dashed border-fd-border p-4 text-sm text-fd-muted"
            >
              {{ t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.LOADING') }}
            </div>
            <div
              v-else-if="!candidates.length"
              class="rounded-md border border-dashed border-fd-border p-4 text-sm text-fd-muted"
            >
              {{ t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.EMPTY') }}
            </div>
            <ul v-else class="m-0 flex list-none flex-col gap-2 p-0">
              <li
                v-for="conversation in candidates"
                :key="conversation.id"
                @click="toggleConversation(conversation.id)"
              >
                <div
                  role="button"
                  tabindex="0"
                  class="flex cursor-pointer gap-3 rounded-md border p-3 transition hover:bg-n-slate-1"
                  :class="
                    isSelectedConversation(conversation.id)
                      ? 'border-fd-primary bg-fd-blueSoft'
                      : 'border-fd-border bg-fd-surface'
                  "
                  :aria-label="
                    t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.SELECT_TICKET', {
                      ticket: `#${ticketNumberOf(conversation)}`,
                    })
                  "
                  @keydown.enter.prevent="toggleConversation(conversation.id)"
                  @keydown.space.prevent="toggleConversation(conversation.id)"
                >
                  <input
                    type="checkbox"
                    class="mt-0.5 size-4 shrink-0 accent-fd-primary"
                    :checked="isSelectedConversation(conversation.id)"
                    :aria-label="
                      t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.SELECT_TICKET', {
                        ticket: `#${ticketNumberOf(conversation)}`,
                      })
                    "
                    @click.stop="toggleConversation(conversation.id)"
                  />
                  <span class="min-w-0 flex-1">
                    <span class="block text-xs font-medium text-fd-primary">
                      {{ `#${ticketNumberOf(conversation)}` }}
                    </span>
                    <span
                      class="mt-1 block truncate text-sm font-semibold text-fd-text"
                    >
                      {{ subjectOf(conversation) }}
                    </span>
                    <span class="mt-1 block text-xs text-fd-muted">
                      {{
                        `${statusOf(conversation)} ${t(
                          'CHAT_LIST.FRESHDESK_CARD.SEPARATOR'
                        )} ${assigneeOf(conversation)}`
                      }}
                    </span>
                    <span class="mt-0.5 block text-xxs text-fd-muted">
                      {{ timeOf(conversation) }}
                    </span>
                  </span>
                  <div class="flex shrink-0 items-start gap-2">
                    <button
                      type="button"
                      class="flex shrink-0 flex-col items-center gap-0.5 rounded-md px-1 py-0.5 text-xxs font-medium transition"
                      :class="[
                        isPrimaryConversation(conversation.id)
                          ? 'w-12 text-fd-primary'
                          : 'w-7 text-fd-muted hover:text-fd-primary',
                      ]"
                      :title="
                        t(
                          'CHAT_LIST.FRESHDESK_DETAIL.MERGE.SELECT_AS_PRIMARY',
                          { ticket: `#${ticketNumberOf(conversation)}` }
                        )
                      "
                      @click.stop="setCandidateAsPrimary(conversation.id)"
                    >
                      <span
                        :class="
                          isPrimaryConversation(conversation.id)
                            ? 'i-lucide-badge-check size-5'
                            : 'i-lucide-badge-check size-5 opacity-60'
                        "
                      />
                      <span
                        v-if="isPrimaryConversation(conversation.id)"
                        class="text-fd-primary"
                      >
                        {{
                          t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.PRIMARY_BADGE')
                        }}
                      </span>
                    </button>
                    <a
                      :href="conversationUrl(conversation)"
                      class="mt-0.5 text-fd-muted hover:text-fd-primary"
                      target="_blank"
                      rel="noopener noreferrer"
                      @click.stop
                    >
                      <span class="i-lucide-external-link size-4" />
                    </a>
                  </div>
                </div>
              </li>
            </ul>
          </section>
        </div>

        <footer
          class="flex items-center justify-end gap-2 border-t border-fd-border px-5 py-4"
        >
          <button
            type="button"
            class="h-9 rounded-md border border-fd-border px-4 text-sm font-medium text-fd-text hover:bg-n-slate-2"
            @click="emit('close')"
          >
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.CANCEL') }}
          </button>
          <button
            type="button"
            class="inline-flex h-9 items-center gap-2 rounded-md bg-fd-primary px-4 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="!hasSelectedTickets || isMerging"
            @click="mergeTicket"
          >
            <span
              v-if="isMerging"
              class="i-lucide-loader-2 size-4 animate-spin"
            />
            <span v-else class="i-lucide-git-merge size-4" />
            {{ t('CHAT_LIST.FRESHDESK_DETAIL.MERGE.CONFIRM') }}
          </button>
        </footer>
      </aside>
    </div>
  </Teleport>
</template>

<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import camelcaseKeys from 'camelcase-keys';
import CallsAPI from 'dashboard/api/calls';
import { useAlert } from 'dashboard/composables';
import { VOICE_CALL_DIRECTION } from 'dashboard/components-next/message/constants';
import { VOICE_CALL_PROVIDERS } from 'dashboard/helper/inbox';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  call: {
    type: Object,
    required: true,
  },
  callInfo: {
    type: Object,
    required: true,
  },
  // 'incoming' | 'outgoing' | 'ongoing'
  state: {
    type: String,
    required: true,
  },
  duration: {
    type: String,
    default: '',
  },
  isMuted: {
    type: Boolean,
    default: false,
  },
  showMute: {
    type: Boolean,
    default: false,
  },
  showTicketAction: {
    type: Boolean,
    default: false,
  },
  isTicketSelectionPersisted: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'accept',
  'reject',
  'end',
  'toggleMute',
  'goToConversation',
  'dismiss',
  'ticketUpdated',
]);

const { t } = useI18n();
const TICKET_PREFIX = '#';
const TEXT = {
  createNewTicket: 'Create new ticket',
  addToExistingTicket: 'Add to existing ticket',
  recentTickets: 'Recent tickets',
  ticketId: 'Ticket ID',
  searchTicketId: 'Search ticket ID',
  loadingTickets: 'Loading tickets...',
  noRecentTickets: 'No recent tickets found.',
  callEnded: 'Call ended',
  openTicketActions: 'Open ticket actions',
  updateTicketError: 'Could not update the call ticket.',
};

const isTicketMenuOpen = ref(false);
const ticketMode = ref('recent');
const ticketSearch = ref('');
const ticketConversations = ref([]);
const isFetchingTickets = ref(false);
const isUpdatingTicket = ref(false);
let ticketSearchTimer = null;

const isOngoing = computed(() => props.state === VOICE_CALL_DIRECTION.ONGOING);
const isIncoming = computed(
  () => props.state === VOICE_CALL_DIRECTION.INCOMING
);
const isOutgoing = computed(
  () => props.state === VOICE_CALL_DIRECTION.OUTGOING
);

const statusIcon = computed(() => {
  if (isOngoing.value) return 'i-ph-phone-call-bold';
  if (isOutgoing.value) return 'i-ph-phone-outgoing-bold';
  return 'i-ph-phone-incoming-bold';
});

const statusLabel = computed(() => {
  if (isOngoing.value) return t('CONVERSATION.VOICE_WIDGET.CALL_IN_PROGRESS');
  if (isOutgoing.value) return t('CONVERSATION.VOICE_WIDGET.OUTGOING_CALL');
  return t('CONVERSATION.VOICE_WIDGET.INCOMING_CALL');
});

const channelIcon = computed(() => {
  if (props.call?.provider === VOICE_CALL_PROVIDERS.WHATSAPP)
    return 'i-ri-whatsapp-fill';
  return 'i-ph-phone-bold';
});

const canManageTicket = computed(
  () =>
    props.showTicketAction &&
    props.call?.callId &&
    (isOngoing.value || props.isTicketSelectionPersisted)
);

const ticketPanelStatusLabel = computed(() =>
  props.isTicketSelectionPersisted ? TEXT.callEnded : statusLabel.value
);

const ticketPanelDuration = computed(() =>
  props.isTicketSelectionPersisted ? '' : props.duration
);

const currentTicketLabel = computed(
  () => props.callInfo.ticketNumber || props.call?.conversationId
);

const fetchTicketConversations = async () => {
  if (!props.callInfo.phoneNumber) {
    ticketConversations.value = [];
    return;
  }

  isFetchingTickets.value = true;
  try {
    const { data } = await CallsAPI.conversations({
      phone_number: props.callInfo.phoneNumber,
      ...(ticketSearch.value.trim() && {
        ticket_id: ticketSearch.value.trim(),
      }),
    });
    ticketConversations.value = camelcaseKeys(data.payload || [], {
      deep: true,
    });
  } catch (_) {
    ticketConversations.value = [];
    useAlert('Could not load tickets for this number.');
  } finally {
    isFetchingTickets.value = false;
  }
};

const openExistingTickets = () => {
  ticketMode.value = 'search';
  ticketSearch.value = '';
  isTicketMenuOpen.value = false;
  fetchTicketConversations();
};

const loadRecentTickets = () => {
  ticketMode.value = 'recent';
  ticketSearch.value = '';
  isTicketMenuOpen.value = false;
  fetchTicketConversations();
};

const attachToTicket = async payload => {
  if (!props.call?.callId) return;
  isUpdatingTicket.value = true;
  try {
    const { data } = await CallsAPI.ticket(props.call.callId, payload);
    emit('ticketUpdated', camelcaseKeys(data.call || {}, { deep: true }));
    ticketMode.value = 'recent';
    isTicketMenuOpen.value = false;
  } catch (error) {
    useAlert(error?.response?.data?.error || TEXT.updateTicketError);
  } finally {
    isUpdatingTicket.value = false;
  }
};

const createNewTicket = () => {
  isTicketMenuOpen.value = false;
  attachToTicket({ ticket_action: 'new' });
};

const selectTicketConversation = conversation =>
  attachToTicket({
    ticket_action: 'existing',
    conversation_id: conversation.ticketNumber || conversation.displayId,
  });

const selectFirstTicketFromSearch = () => {
  if (ticketMode.value !== 'search' || !ticketConversations.value.length) {
    return;
  }

  const query = ticketSearch.value.trim();
  const exactTicket = ticketConversations.value.find(conversation =>
    [conversation.ticketNumber, conversation.displayId?.toString()].includes(
      query
    )
  );
  selectTicketConversation(exactTicket || ticketConversations.value[0]);
};

watch(ticketSearch, () => {
  if (ticketMode.value !== 'search') return;
  clearTimeout(ticketSearchTimer);
  ticketSearchTimer = setTimeout(fetchTicketConversations, 250);
});

watch(
  () => [
    canManageTicket.value,
    props.callInfo.phoneNumber,
    props.call?.callSid,
  ],
  ([enabled]) => {
    if (!enabled) return;
    loadRecentTickets();
  },
  { immediate: true }
);

onBeforeUnmount(() => {
  clearTimeout(ticketSearchTimer);
});
</script>

<template>
  <div
    v-if="canManageTicket"
    class="w-[316px] overflow-hidden rounded-md border border-n-weak bg-white shadow-xl dark:bg-n-solid-2"
  >
    <div class="bg-[#123852] text-white">
      <div class="flex h-14 items-center gap-3 px-4">
        <div
          class="grid size-8 shrink-0 place-content-center rounded-full bg-[#9ee6aa] text-sm font-semibold text-[#123852]"
        >
          {{ TICKET_PREFIX }}
        </div>
        <div class="min-w-0 flex-1">
          <p class="mb-0 truncate text-sm font-semibold leading-5">
            {{ callInfo.phoneNumber || callInfo.contactName }}
          </p>
          <p class="mb-0 truncate text-xs leading-4 text-white/75">
            {{ ticketPanelStatusLabel }}
          </p>
        </div>
        <span
          v-if="ticketPanelDuration"
          class="shrink-0 rounded-full bg-white px-2 py-0.5 text-xs font-medium tabular-nums text-[#123852]"
        >
          {{ ticketPanelDuration }}
        </span>
        <button
          v-if="isTicketSelectionPersisted"
          type="button"
          class="grid size-7 shrink-0 place-content-center rounded-full bg-white/10 text-white hover:bg-white/20"
          @click="$emit('dismiss')"
        >
          <span class="i-lucide-x size-4" />
        </button>
        <button
          v-else
          type="button"
          class="grid size-7 shrink-0 place-content-center rounded-full bg-white text-[#ef4b6f]"
          disabled
        >
          <span class="i-lucide-pause size-3.5" />
        </button>
      </div>

      <div class="flex h-10 items-center gap-2 bg-[#0f3148] px-4">
        <button
          type="button"
          class="flex h-7 min-w-0 flex-1 items-center justify-between gap-2 rounded bg-white/10 px-3 text-left text-xs font-medium text-white hover:bg-white/15"
          @click="loadRecentTickets"
        >
          <span class="truncate">{{ TEXT.recentTickets }}</span>
          <span class="i-lucide-chevron-down size-3.5 shrink-0 text-white/75" />
        </button>
        <button
          type="button"
          class="grid size-8 place-content-center rounded-full text-white hover:bg-white/10 disabled:cursor-not-allowed disabled:text-white/35"
          :disabled="!call?.conversationId"
          @click="$emit('goToConversation')"
        >
          <span class="i-lucide-link size-4" />
        </button>
        <div class="relative">
          <button
            type="button"
            class="grid size-8 place-content-center rounded-full bg-white/10 text-white hover:bg-white/20 disabled:cursor-not-allowed disabled:opacity-60"
            :title="TEXT.openTicketActions"
            :disabled="isUpdatingTicket"
            @click="isTicketMenuOpen = !isTicketMenuOpen"
          >
            <span class="i-lucide-plus size-4" />
          </button>
          <div
            v-if="isTicketMenuOpen"
            class="absolute right-0 top-9 z-[80] w-[190px] overflow-hidden rounded-md border border-n-weak bg-white py-1 text-n-slate-12 shadow-xl dark:bg-n-solid-2 dark:text-n-slate-12"
          >
            <button
              type="button"
              class="flex h-9 w-full items-center px-3 text-left text-sm hover:bg-n-alpha-1 disabled:cursor-not-allowed disabled:opacity-60"
              :disabled="isUpdatingTicket"
              @click="createNewTicket"
            >
              {{ TEXT.createNewTicket }}
            </button>
            <button
              type="button"
              class="flex h-9 w-full items-center px-3 text-left text-sm hover:bg-n-alpha-1 disabled:cursor-not-allowed disabled:opacity-60"
              :disabled="isUpdatingTicket"
              @click="openExistingTickets"
            >
              {{ TEXT.addToExistingTicket }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="h-[312px] overflow-y-auto bg-white dark:bg-n-solid-2">
      <div v-if="ticketMode === 'search'" class="border-b border-n-weak p-3">
        <label
          class="flex h-10 items-center gap-2 rounded border border-n-weak bg-n-slate-1 px-3 dark:bg-n-solid-3"
        >
          <span class="i-lucide-search size-4 text-n-slate-10" />
          <input
            v-model="ticketSearch"
            class="min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-n-slate-10"
            :placeholder="TEXT.searchTicketId"
            inputmode="numeric"
            @keydown.enter.prevent="selectFirstTicketFromSearch"
          />
        </label>
      </div>

      <div
        v-if="isFetchingTickets"
        class="flex h-full items-center justify-center text-sm text-n-slate-11"
      >
        {{ TEXT.loadingTickets }}
      </div>
      <div
        v-else-if="!ticketConversations.length"
        class="flex h-full flex-col items-center justify-center gap-3 text-sm text-[#123852]"
      >
        <div
          class="grid size-16 place-content-center rounded-full bg-[#eef3f6] text-[#8ba2b2]"
        >
          <span class="i-lucide-ticket size-8" />
        </div>
        <span>{{ TEXT.noRecentTickets }}</span>
      </div>
      <template v-else>
        <button
          v-for="conversation in ticketConversations"
          :key="conversation.id"
          type="button"
          class="group flex h-[58px] w-full items-center gap-3 border-b border-n-weak px-4 text-left transition-colors hover:bg-[#f4f8fb] disabled:cursor-not-allowed disabled:opacity-60"
          :disabled="isUpdatingTicket"
          @click="selectTicketConversation(conversation)"
        >
          <span
            class="grid size-8 shrink-0 place-content-center rounded-full bg-[#eef3f6] text-xs font-semibold text-[#123852]"
          >
            {{ TICKET_PREFIX }}
          </span>
          <span class="min-w-0 flex-1">
            <span class="block truncate text-sm font-semibold text-[#123852]">
              <span>{{ TICKET_PREFIX }}</span>
              <span>{{
                conversation.ticketNumber || conversation.displayId
              }}</span>
            </span>
            <span class="block truncate text-xs text-n-slate-10">
              {{ conversation.subject || conversation.inbox?.name }}
            </span>
          </span>
          <span
            class="i-lucide-check size-4 shrink-0 text-n-brand opacity-0 transition-opacity group-hover:opacity-100"
          />
        </button>
      </template>
    </div>

    <div
      class="flex h-14 items-center justify-between border-t border-n-weak bg-white px-4 dark:bg-n-solid-2"
    >
      <button
        type="button"
        class="grid size-8 place-content-center rounded-full text-[#123852] hover:bg-n-alpha-1"
        :disabled="!currentTicketLabel"
        @click="$emit('goToConversation')"
      >
        <span class="i-lucide-file size-4" />
      </button>
      <button
        type="button"
        class="grid size-8 place-content-center rounded-full text-[#123852] opacity-70"
        disabled
      >
        <span class="i-lucide-phone-forwarded size-4" />
      </button>
      <button
        type="button"
        class="grid size-8 place-content-center rounded-full text-[#123852] opacity-70"
        disabled
      >
        <span class="i-lucide-pause size-4" />
      </button>
      <button
        type="button"
        class="grid size-8 place-content-center rounded-full text-[#123852] hover:bg-n-alpha-1"
        :class="{ 'bg-[#e8f6f3] text-[#0f766e]': !isMuted }"
        :disabled="!showMute || isTicketSelectionPersisted"
        @click="$emit('toggleMute')"
      >
        <span
          :class="isMuted ? 'i-lucide-mic-off size-4' : 'i-lucide-mic size-4'"
        />
      </button>
      <button
        type="button"
        class="grid size-8 place-content-center rounded-full text-[#123852] opacity-70"
        disabled
      >
        <span class="i-lucide-grid-3x3 size-4" />
      </button>
      <button
        type="button"
        class="grid size-8 place-content-center rounded-full text-[#123852] opacity-70"
        disabled
      >
        <span class="i-lucide-users size-4" />
      </button>
      <button
        type="button"
        class="grid size-9 place-content-center rounded-full bg-[#dc3345] text-white hover:bg-[#c72d3e]"
        @click="isTicketSelectionPersisted ? $emit('dismiss') : $emit('end')"
      >
        <span class="i-lucide-phone size-4 rotate-[135deg]" />
      </button>
    </div>
  </div>

  <div
    v-else
    class="flex flex-col gap-1 pt-4 bg-n-call-widget rounded-2xl shadow-xl outline outline-1 outline-n-call-widget-border backdrop-blur-md"
    :class="call?.conversationId ? 'pb-2' : 'pb-4'"
  >
    <!-- Top section: status badge + location/inbox + duration -->
    <div class="flex flex-col gap-3 pb-3 border-b border-n-call-widget-border">
      <div class="flex items-center gap-2 px-4">
        <!-- Ongoing: status badge on left -->
        <div v-if="isOngoing" class="flex items-center gap-1.5 shrink-0">
          <Icon :icon="statusIcon" class="size-3.5 text-n-teal-9 shrink-0" />
          <span class="text-xs font-medium text-n-teal-9 tracking-tight">
            {{ statusLabel }}
          </span>
        </div>

        <!-- Caller location (city, country) or fallback to channel + inbox name -->
        <div class="flex items-center gap-1.5 min-w-0 flex-1">
          <span
            v-if="callInfo.hasLocation && callInfo.countryFlag"
            class="text-sm leading-none shrink-0"
          >
            {{ callInfo.countryFlag }}
          </span>
          <Icon
            v-else-if="!isOngoing"
            :icon="channelIcon"
            class="size-3.5 text-n-call-widget-sub-text shrink-0"
          />
          <span
            class="text-xs font-medium text-n-call-widget-sub-text tracking-tight truncate"
          >
            {{ callInfo.location }}
          </span>
        </div>

        <!-- Ongoing: duration on right -->
        <p
          v-if="isOngoing"
          class="font-display text-base font-medium text-n-call-widget-sub-text shrink-0 mb-0 tabular-nums tracking-tight"
        >
          {{ duration }}
        </p>
        <!-- Incoming/Outgoing: status badge on right -->
        <div v-else class="flex items-center gap-1.5 shrink-0">
          <Icon :icon="statusIcon" class="size-3.5 text-n-teal-9 shrink-0" />
          <span class="text-xs font-medium text-n-teal-9 tracking-tight">
            {{ statusLabel }}
          </span>
          <!-- Dismiss: removes the notification from the UI without declining.
               Incoming only — outgoing/ongoing calls are ended via the call
               controls, not silently dismissed. -->
          <NextButton
            v-if="isIncoming"
            v-tooltip.top="$t('CONVERSATION.VOICE_WIDGET.DISMISS_CALL')"
            icon="i-ph-x-bold"
            slate
            ghost
            xs
            class="!rounded-full -my-1 -me-1 !text-n-call-widget-sub-text"
            @click="$emit('dismiss')"
          />
        </div>
      </div>

      <!-- Main row: avatar + name/phone + actions -->
      <div class="flex items-center gap-3 px-4">
        <div class="shrink-0">
          <Avatar
            :src="callInfo.avatar"
            :name="callInfo.contactName"
            :size="40"
          />
        </div>
        <div class="flex-1 min-w-0">
          <p
            class="font-display text-sm font-medium text-n-call-widget-text truncate mb-0.5 tracking-tight leading-tight"
          >
            {{ callInfo.contactName }}
          </p>
          <p
            v-if="callInfo.phoneNumber"
            class="text-sm text-n-call-widget-sub-text truncate mb-0 tracking-tight leading-tight"
          >
            {{ callInfo.phoneNumber }}
          </p>
        </div>

        <!-- Actions -->
        <div class="relative flex items-center gap-2 shrink-0">
          <NextButton
            v-if="canManageTicket"
            icon="i-lucide-plus"
            slate
            faded
            class="!rounded-full"
            @click="isTicketMenuOpen = !isTicketMenuOpen"
          />
          <div
            v-if="isTicketMenuOpen"
            class="absolute right-0 top-10 z-[80] w-[188px] overflow-hidden rounded-md border border-n-weak bg-white py-1 text-n-slate-12 shadow-xl dark:bg-n-solid-2 dark:text-n-slate-12"
          >
            <button
              type="button"
              class="flex h-9 w-full items-center px-3 text-left text-sm hover:bg-n-alpha-1"
              @click="createNewTicket"
            >
              {{ TEXT.createNewTicket }}
            </button>
            <button
              type="button"
              class="flex h-9 w-full items-center px-3 text-left text-sm hover:bg-n-alpha-1"
              @click="openExistingTickets"
            >
              {{ TEXT.addToExistingTicket }}
            </button>
          </div>
          <!-- Mute toggle (WhatsApp ongoing only) -->
          <NextButton
            v-if="isOngoing && showMute"
            v-tooltip.top="
              isMuted
                ? $t('CONVERSATION.VOICE_WIDGET.UNMUTE')
                : $t('CONVERSATION.VOICE_WIDGET.MUTE')
            "
            :icon="
              isMuted ? 'i-ph-microphone-slash-bold' : 'i-ph-microphone-bold'
            "
            :variant="isMuted ? 'solid' : 'faded'"
            :color="isMuted ? 'amber' : 'teal'"
            class="!rounded-full"
            @click="$emit('toggleMute')"
          />

          <!-- Accept call (incoming only) -->
          <NextButton
            v-if="isIncoming"
            v-tooltip.top="$t('CONVERSATION.VOICE_WIDGET.JOIN_CALL')"
            icon="i-ph-phone-bold"
            teal
            class="!rounded-full"
            @click="$emit('accept')"
          />

          <!-- Reject / end call (all states) -->
          <NextButton
            v-tooltip.top="
              isOngoing
                ? $t('CONVERSATION.VOICE_WIDGET.END_CALL')
                : $t('CONVERSATION.VOICE_WIDGET.REJECT_CALL')
            "
            icon="i-ph-phone-bold"
            ruby
            class="!rounded-full rotate-[135deg]"
            @click="isOngoing ? $emit('end') : $emit('reject')"
          />
        </div>
      </div>
    </div>

    <div
      v-if="ticketMode === 'existing'"
      class="mx-3 mb-2 overflow-hidden rounded-lg border border-n-call-widget-border bg-white dark:bg-n-solid-2"
    >
      <div class="flex h-11 items-center gap-2 border-b border-n-weak px-3">
        <button
          type="button"
          class="grid size-7 place-content-center rounded text-n-slate-10 hover:bg-n-alpha-1 hover:text-n-slate-12"
          @click="ticketMode = null"
        >
          <span class="i-lucide-chevron-left size-4" />
        </button>
        <span class="min-w-0 flex-1 text-sm font-medium text-n-slate-12">
          {{ TEXT.addToExistingTicket }}
        </span>
      </div>
      <div class="p-3">
        <label
          class="flex h-10 items-center gap-2 rounded border border-n-weak bg-n-slate-1 px-3 dark:bg-n-solid-3"
        >
          <span class="i-lucide-search size-4 text-n-slate-10" />
          <input
            v-model="ticketSearch"
            class="min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-n-slate-10"
            :placeholder="TEXT.ticketId"
            inputmode="numeric"
          />
        </label>
      </div>
      <div class="max-h-[180px] overflow-y-auto">
        <div
          v-if="isFetchingTickets"
          class="flex h-20 items-center justify-center text-sm text-n-slate-11"
        >
          {{ TEXT.loadingTickets }}
        </div>
        <div
          v-else-if="!ticketConversations.length"
          class="flex h-24 items-center justify-center text-sm text-n-slate-11"
        >
          {{ TEXT.noRecentTickets }}
        </div>
        <template v-else>
          <button
            v-for="conversation in ticketConversations"
            :key="conversation.id"
            type="button"
            class="group flex h-[52px] w-full items-center gap-3 border-b border-n-weak px-3 text-left transition-colors hover:bg-n-alpha-1"
            @click="selectTicketConversation(conversation)"
          >
            <span
              class="grid size-7 shrink-0 place-content-center rounded-full bg-n-slate-2 text-xs font-semibold text-n-slate-11"
            >
              {{ TICKET_PREFIX }}
            </span>
            <span class="min-w-0 flex-1">
              <span class="block truncate text-sm font-medium text-n-slate-12">
                <span>{{ TICKET_PREFIX }}</span>
                <span>{{
                  conversation.ticketNumber || conversation.displayId
                }}</span>
              </span>
              <span class="block truncate text-xs text-n-slate-10">
                {{ conversation.subject || conversation.inbox?.name }}
              </span>
            </span>
            <span
              class="i-lucide-check size-4 shrink-0 text-n-brand opacity-0 transition-opacity group-hover:opacity-100"
            />
          </button>
        </template>
      </div>
    </div>

    <!-- Footer: go to conversation thread -->
    <NextButton
      v-if="call?.conversationId"
      slate
      ghost
      trailing-icon
      class="!justify-between !px-2 !mx-2"
      @click="$emit('goToConversation')"
    >
      <template #icon>
        <span
          class="flex items-center gap-1 text-n-call-widget-sub-text group-hover:text-n-call-widget-text"
        >
          <Icon
            icon="i-ph-chat-circle-text-bold"
            class="size-3.5 text-n-call-widget-sub-text shrink-0"
          />
          <span class="text-sm tracking-tight tabular-nums">
            <span>{{ TICKET_PREFIX }}</span>
            <span>{{ callInfo.ticketNumber || call.conversationId }}</span>
          </span>
          <Icon
            icon="i-ph-caret-right-bold"
            class="size-3 text-n-call-widget-sub-text shrink-0"
          />
        </span>
      </template>
      <span
        class="text-sm text-n-call-widget-sub-text tracking-tight group-hover:text-n-call-widget-text"
      >
        {{ $t('CONVERSATION.VOICE_WIDGET.GO_TO_CONVERSATION') }}
      </span>
    </NextButton>
  </div>
</template>

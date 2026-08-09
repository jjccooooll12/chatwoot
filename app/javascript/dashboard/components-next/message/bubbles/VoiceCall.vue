<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import camelcaseKeys from 'camelcase-keys';
import { useMapGetter } from 'dashboard/composables/store';
import { useMessageContext } from '../provider.js';
import {
  VOICE_CALL_STATUS,
  VOICE_CALL_DIRECTION,
  VOICE_CALL_OUTBOUND_INIT_STATUS,
  VOICE_CALL_END_REASON,
  MESSAGE_TYPES,
  ATTACHMENT_TYPES,
} from '../constants';
import { useCallActions } from 'dashboard/composables/useCallSession';
import { useWhatsappCallSession } from 'dashboard/composables/useWhatsappCallSession';
import CallsAPI from 'dashboard/api/calls';
import { useCallsStore } from 'dashboard/stores/calls';
import { VOICE_CALL_PROVIDERS } from 'dashboard/helper/inbox';
import { formatDuration } from 'shared/helpers/timeHelper';
import { shortenAgentName } from 'shared/helpers/agentNameHelper';
import { useAlert } from 'dashboard/composables';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import BaseBubble from 'next/message/bubbles/Base.vue';
import AudioChip from 'next/message/chips/Audio.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const LABEL_MAP = {
  [VOICE_CALL_STATUS.IN_PROGRESS]: 'CONVERSATION.VOICE_CALL.CALL_IN_PROGRESS',
  [VOICE_CALL_STATUS.COMPLETED]: 'CONVERSATION.VOICE_CALL.CALL_ENDED',
};

const ICON_MAP = {
  [VOICE_CALL_STATUS.IN_PROGRESS]: 'i-ph-phone-call-bold',
  [VOICE_CALL_STATUS.COMPLETED]: 'i-ph-phone-bold',
  [VOICE_CALL_STATUS.NO_ANSWER]: 'i-ph-phone-x-bold',
  [VOICE_CALL_STATUS.FAILED]: 'i-ph-phone-x-bold',
  [VOICE_CALL_STATUS.REJECTED]: 'i-ph-phone-x-bold',
};

const TICKET_PREFIX = '#';
const TEXT = {
  createNewTicket: 'Create new ticket',
  addToExistingTicket: 'Add to existing ticket',
  ticketId: 'Ticket ID',
  loadingTickets: 'Loading tickets...',
  noRecentTickets: 'No recent tickets found.',
  ticketUpdated: 'Call ticket updated.',
  loadTicketsError: 'Could not load tickets for this number.',
  updateTicketError: 'Could not update the call ticket.',
};

const { t } = useI18n();
const store = useStore();
const {
  call,
  attachments,
  contentAttributes,
  conversationId,
  currentUserId,
  inboxId,
  sender,
  messageType,
} = useMessageContext();
const { joinCall, endCall, activeCall, hasActiveCall, isJoining } =
  useCallActions();
const whatsappCallSession = useWhatsappCallSession();
const callsStore = useCallsStore();
const contactsUiFlags = useMapGetter('contacts/getUIFlags');
const isStartingTwilioCall = ref(false);
const isTicketMenuOpen = ref(false);
const ticketMode = ref(null);
const ticketSearch = ref('');
const ticketConversations = ref([]);
const isFetchingTickets = ref(false);
let ticketSearchTimer = null;
const isInitiatingCall = computed(
  () => contactsUiFlags.value?.isInitiatingCall || isStartingTwilioCall.value
);

const status = computed(() => call.value?.status);
// Server-side call records use `outgoing`/`incoming`, while the Pinia store
// and a few API hops normalise to `outbound`/`inbound`. Accept either so the
// bubble label matches the message orientation no matter the source.
const isOutbound = computed(() => {
  const dir = call.value?.direction;
  if (
    dir === VOICE_CALL_DIRECTION.OUTGOING ||
    dir === VOICE_CALL_DIRECTION.OUTBOUND
  )
    return true;
  if (
    dir === VOICE_CALL_DIRECTION.INCOMING ||
    dir === VOICE_CALL_DIRECTION.INBOUND
  )
    return false;
  // Fall back to the message orientation: agent-authored messages sit on the
  // right (outbound) and contact-authored ones on the left.
  return messageType.value === MESSAGE_TYPES.OUTGOING;
});
const isWhatsapp = computed(
  () => call.value?.provider === VOICE_CALL_PROVIDERS.WHATSAPP
);
const isFailed = computed(() =>
  [
    VOICE_CALL_STATUS.NO_ANSWER,
    VOICE_CALL_STATUS.FAILED,
    VOICE_CALL_STATUS.REJECTED,
  ].includes(status.value)
);
const isMissedInbound = computed(() => isFailed.value && !isOutbound.value);
const endReason = computed(() => call.value?.endReason);
const wasDeclinedByAgent = computed(
  () =>
    isMissedInbound.value &&
    endReason.value === VOICE_CALL_END_REASON.AGENT_REJECTED
);
const acceptedByAgentId = computed(() => call.value?.acceptedByAgentId);
const conversationAssignee = computed(() => {
  const conversation = store.getters.getConversationById?.(
    conversationId?.value
  );
  return conversation?.meta?.assignee || null;
});
const displayAgentName = computed(() => {
  if (call.value?.acceptedByAgentName) {
    return shortenAgentName(call.value.acceptedByAgentName);
  }
  if (acceptedByAgentId.value) {
    const agent = store.getters['agents/getAgentById'](acceptedByAgentId.value);
    if (agent?.available_name) return shortenAgentName(agent.available_name);
    if (agent?.name) return shortenAgentName(agent.name);
  }
  return shortenAgentName(conversationAssignee.value?.name) || null;
});

const audioAttachment = computed(() =>
  (attachments?.value || []).find(a => a.fileType === ATTACHMENT_TYPES.AUDIO)
);

const recordingAttachment = computed(() => {
  if (audioAttachment.value) return audioAttachment.value;
  const url = call.value?.recordingUrl;
  if (!url) return null;
  return {
    dataUrl: url,
    fileType: ATTACHMENT_TYPES.AUDIO,
    extension: 'wav',
    transcribedText: call.value?.transcript || '',
  };
});

const durationSeconds = computed(() => {
  const fromCall = call.value?.durationSeconds || call.value?.duration_seconds;
  if (fromCall != null) return fromCall;
  const data = contentAttributes?.value?.data;
  return data?.durationSeconds || data?.duration_seconds;
});

const formattedDuration = computed(() => formatDuration(durationSeconds.value));

// Agent who handled the call (initiator on outbound, answerer on inbound), taken
// strictly from the persisted accept fields — never the conversation's current
// assignee, which would mis-attribute a historical call after a reassignment.
const handlerName = computed(() => {
  if (call.value?.acceptedByAgentName) {
    return shortenAgentName(call.value.acceptedByAgentName);
  }
  if (!acceptedByAgentId.value) return null;
  const agent = store.getters['agents/getAgentById'](acceptedByAgentId.value);
  return shortenAgentName(agent?.available_name || agent?.name) || null;
});

const handledBy = computed(() =>
  handlerName.value
    ? t('CONVERSATION.VOICE_CALL.HANDLED_BY', { agentName: handlerName.value })
    : null
);

const labelKey = computed(() => {
  if (LABEL_MAP[status.value]) return LABEL_MAP[status.value];
  if (isFailed.value) {
    if (isOutbound.value) return 'CONVERSATION.VOICE_CALL.OUTGOING_CALL';
    return recordingAttachment.value
      ? 'CONVERSATION.VOICE_CALL.VOICEMAIL'
      : 'CONVERSATION.VOICE_CALL.MISSED_CALL';
  }
  // RINGING or an as-yet-unknown/initial status: orient purely by direction so an
  // outbound call never falls through to the "Incoming call" label.
  return isOutbound.value
    ? 'CONVERSATION.VOICE_CALL.OUTGOING_CALL'
    : 'CONVERSATION.VOICE_CALL.INCOMING_CALL';
});

const subtext = computed(() => {
  // Completed: "Handled by {agent} · 0:42" (drops either part when absent).
  if (status.value === VOICE_CALL_STATUS.COMPLETED) {
    return [handledBy.value, formattedDuration.value]
      .filter(Boolean)
      .join(' · ');
  }
  if (status.value === VOICE_CALL_STATUS.IN_PROGRESS) {
    return handledBy.value;
  }
  if (isFailed.value) {
    // Missed/failed calls have no handler, so keep the reason rather than "Handled by".
    if (isOutbound.value) {
      return handledBy.value;
    }
    if (wasDeclinedByAgent.value && displayAgentName.value) {
      return t('CONVERSATION.VOICE_CALL.MISSED_CALL_DECLINED_BY', {
        agentName: displayAgentName.value,
      });
    }
    return t('CONVERSATION.VOICE_CALL.MISSED_CALL_INBOUND_SUBTEXT');
  }
  // RINGING or an as-yet-unknown/initial status.
  if (isOutbound.value) {
    return handledBy.value || t('CONVERSATION.VOICE_CALL.CALLING');
  }
  return t('CONVERSATION.VOICE_CALL.NOT_ANSWERED_YET');
});

const iconName = computed(() => {
  if (isFailed.value && isOutbound.value) return 'i-ph-phone-outgoing-bold';
  if (ICON_MAP[status.value]) return ICON_MAP[status.value];
  return isOutbound.value
    ? 'i-ph-phone-outgoing-bold'
    : 'i-ph-phone-incoming-bold';
});

// Subtle icon container — matches the design's tonal swatch over the bubble bg.
// Status drives the accent: teal for live, ruby for missed, neutral otherwise.
const iconContainerClass = computed(() => {
  if (status.value === VOICE_CALL_STATUS.IN_PROGRESS) {
    return 'bg-n-teal-3 text-n-teal-11';
  }
  if (status.value === VOICE_CALL_STATUS.RINGING) {
    return 'bg-n-teal-3 text-n-teal-11';
  }
  if (isMissedInbound.value) {
    return 'bg-n-alpha-2 text-n-ruby-9';
  }
  return 'bg-n-alpha-2 text-n-slate-12';
});

const callSid = computed(() => call.value?.providerCallId);
const callId = computed(() => call.value?.id);
const callPhoneNumber = computed(
  () =>
    call.value?.toNumber ||
    call.value?.to_number ||
    sender.value?.phone_number ||
    sender.value?.phoneNumber ||
    ''
);
const canManageTicket = computed(() => isOutbound.value && !!callId.value);

const canJoinCall = computed(() => {
  if (status.value !== VOICE_CALL_STATUS.RINGING) return false;
  if (isOutbound.value) return false;
  if (acceptedByAgentId.value) return false;
  if (!callSid.value || !inboxId.value || !conversationId.value) return false;
  if (hasActiveCall.value && activeCall.value?.callSid === callSid.value)
    return false;
  const assignee = conversationAssignee.value;
  if (assignee?.id && assignee.id !== currentUserId.value) return false;
  return true;
});

const handleJoinCall = async () => {
  if (!canJoinCall.value || isJoining.value) return;

  if (hasActiveCall.value && activeCall.value?.callSid !== callSid.value) {
    await endCall({
      conversationId: activeCall.value.conversationId,
      inboxId: activeCall.value.inboxId,
      callSid: activeCall.value.callSid,
    });
  }

  await joinCall({
    conversationId: conversationId.value,
    inboxId: inboxId.value,
    callSid: callSid.value,
  });
};

const canCallBack = computed(
  () =>
    isMissedInbound.value &&
    !!inboxId.value &&
    !!conversationId.value &&
    !hasActiveCall.value &&
    !callsStore.hasIncomingCall
);

const handleCallBack = async () => {
  if (!canCallBack.value || isInitiatingCall.value) return;
  try {
    if (isWhatsapp.value) {
      const response = await whatsappCallSession.initiateOutboundCall({
        conversationId: conversationId.value,
      });
      if (response?.status === VOICE_CALL_OUTBOUND_INIT_STATUS.LOCKED) return;
      // Permission template path returns no call id — show banner, no widget yet.
      if (!response?.id) {
        useAlert(
          response?.status ===
            VOICE_CALL_OUTBOUND_INIT_STATUS.PERMISSION_PENDING
            ? t('CONVERSATION.HEADER.WHATSAPP_CALL_PERMISSION_PENDING')
            : t('CONVERSATION.HEADER.WHATSAPP_CALL_PERMISSION_REQUESTED')
        );
        return;
      }
      callsStore.addCall({
        callSid: response.call_id,
        callId: response.id,
        conversationId: conversationId.value,
        inboxId: inboxId.value,
        callDirection: VOICE_CALL_DIRECTION.OUTBOUND,
        provider: VOICE_CALL_PROVIDERS.WHATSAPP,
      });
      return;
    }
    isStartingTwilioCall.value = true;
    const { data: response } = await CallsAPI.create({
      contact_id: sender.value?.id,
      inbox_id: inboxId.value,
      conversation_id: conversationId.value,
      phone_number: sender.value?.phone_number || sender.value?.phoneNumber,
    });
    callsStore.addCall({
      callSid: response?.call_sid,
      callId: response?.call?.id,
      conversationId: response?.conversation_id ?? conversationId.value,
      inboxId: inboxId.value,
      callDirection: VOICE_CALL_DIRECTION.OUTBOUND,
      provider: VOICE_CALL_PROVIDERS.TWILIO,
      phoneNumber: sender.value?.phone_number || sender.value?.phoneNumber,
    });
  } catch (error) {
    useAlert(error?.message || t('CONTACT_PANEL.CALL_FAILED'));
  } finally {
    isStartingTwilioCall.value = false;
  }
};

const fetchTicketConversations = async () => {
  if (!callPhoneNumber.value) {
    ticketConversations.value = [];
    return;
  }

  isFetchingTickets.value = true;
  try {
    const { data } = await CallsAPI.conversations({
      phone_number: callPhoneNumber.value,
      ...(ticketSearch.value.trim() && {
        ticket_id: ticketSearch.value.trim(),
      }),
    });
    ticketConversations.value = camelcaseKeys(data.payload || [], {
      deep: true,
    });
  } catch (_) {
    ticketConversations.value = [];
    useAlert(TEXT.loadTicketsError);
  } finally {
    isFetchingTickets.value = false;
  }
};

const openExistingTickets = () => {
  ticketMode.value = 'existing';
  isTicketMenuOpen.value = false;
  fetchTicketConversations();
};

const attachToTicket = async payload => {
  if (!callId.value) return;
  try {
    await CallsAPI.ticket(callId.value, payload);
    ticketMode.value = null;
    isTicketMenuOpen.value = false;
    useAlert(TEXT.ticketUpdated);
  } catch (error) {
    useAlert(error?.response?.data?.error || TEXT.updateTicketError);
  }
};

const createNewTicket = () => attachToTicket({ ticket_action: 'new' });

const selectTicketConversation = conversation =>
  attachToTicket({
    ticket_action: 'existing',
    conversation_id: conversation.ticketNumber || conversation.displayId,
  });

watch(ticketSearch, () => {
  if (ticketMode.value !== 'existing') return;
  clearTimeout(ticketSearchTimer);
  ticketSearchTimer = setTimeout(fetchTicketConversations, 250);
});

onBeforeUnmount(() => {
  clearTimeout(ticketSearchTimer);
});
</script>

<template>
  <BaseBubble class="!p-3 !max-w-md min-w-[240px]" hide-meta>
    <div class="flex flex-col gap-3 w-full">
      <!-- Header row: icon + title + duration/subtext -->
      <div class="flex gap-2.5 items-start">
        <div
          class="flex justify-center items-center rounded-xl size-11 shrink-0"
          :class="iconContainerClass"
        >
          <Icon class="size-4" :icon="iconName" />
        </div>
        <div class="flex flex-col flex-1 min-w-0 self-center">
          <span
            class="font-display text-sm font-medium leading-tight truncate tracking-tight"
          >
            {{ $t(labelKey) }}
          </span>
          <span
            v-if="subtext"
            class="text-sm leading-tight truncate tracking-tight opacity-75"
          >
            {{ subtext }}
          </span>
        </div>
        <div v-if="canManageTicket" class="relative shrink-0">
          <NextButton
            icon="i-lucide-plus"
            slate
            faded
            xs
            class="!rounded-full"
            @click="isTicketMenuOpen = !isTicketMenuOpen"
          />
          <div
            v-if="isTicketMenuOpen"
            class="absolute right-0 top-8 z-[80] w-[188px] overflow-hidden rounded-md border border-n-weak bg-white py-1 text-n-slate-12 shadow-xl dark:bg-n-solid-2 dark:text-n-slate-12"
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
        </div>
      </div>

      <div
        v-if="ticketMode === 'existing'"
        class="overflow-hidden rounded-lg border border-n-weak bg-white dark:bg-n-solid-2"
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
                <span
                  class="block truncate text-sm font-medium text-n-slate-12"
                >
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

      <!-- Audio player (when there's a recording) -->
      <AudioChip
        v-if="recordingAttachment"
        :attachment="recordingAttachment"
        show-transcribed-text
      />

      <!-- Call back button (missed inbound) -->
      <NextButton
        v-if="canCallBack"
        type="button"
        :label="$t('CONVERSATION.VOICE_CALL.CALL_BACK')"
        icon="i-ph-phone-bold"
        teal
        class="!rounded-full"
        :disabled="isInitiatingCall"
        @click="handleCallBack"
      />

      <!-- Join call button (ringing inbound) -->
      <NextButton
        v-if="canJoinCall"
        type="button"
        :label="$t('CONVERSATION.VOICE_CALL.JOIN_CALL')"
        icon="i-ph-phone-bold"
        teal
        class="!rounded-full"
        :disabled="isJoining"
        @click="handleJoinCall"
      />
    </div>
  </BaseBubble>
</template>

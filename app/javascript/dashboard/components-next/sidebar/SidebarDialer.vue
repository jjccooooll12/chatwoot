<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import { vOnClickOutside } from '@vueuse/components';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import camelcaseKeys from 'camelcase-keys';
import ContactAPI from 'dashboard/api/contacts';
import CallsAPI from 'dashboard/api/calls';
import {
  isVoiceCallEnabled,
  getVoiceCallProvider,
  VOICE_CALL_PROVIDERS,
} from 'dashboard/helper/inbox';
import { useCallsStore } from 'dashboard/stores/calls';
import { useWhatsappCallSession } from 'dashboard/composables/useWhatsappCallSession';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { dynamicTimeStrict } from 'shared/helpers/timeHelper';
import countries from 'shared/constants/countries';
import {
  VOICE_CALL_DIRECTION,
  VOICE_CALL_OUTBOUND_INIT_STATUS,
} from 'dashboard/components-next/message/constants';

const props = defineProps({
  isCollapsed: {
    type: Boolean,
    default: true,
  },
});

const COMMON_COUNTRY_IDS = [
  'IT',
  'US',
  'GB',
  'DE',
  'FR',
  'ES',
  'NL',
  'BE',
  'PL',
  'CH',
  'AT',
  'IE',
  'PT',
  'SE',
  'DK',
  'NO',
  'CA',
  'AU',
];

const COUNTRY_OPTIONS = [
  ...COMMON_COUNTRY_IDS.map(id =>
    countries.find(country => country.id === id)
  ).filter(Boolean),
  ...countries.filter(country => !COMMON_COUNTRY_IDS.includes(country.id)),
].map(country => ({
  id: country.id,
  name: country.name,
  code: country.dial_code,
}));

const TEXT = {
  phoneTitle: 'Phone',
  openPhoneDialer: 'Open phone dialer',
  countryCode: 'Country code',
  countrySearchPlaceholder: 'Search country or code',
  closeCountrySearch: 'Close country search',
  noCountriesFound: 'No countries found.',
  voiceInbox: 'Voice inbox',
  inputPlaceholder: 'Type name or number to call',
  recentCalls: 'Recent calls',
  viewAll: 'View all',
  noVoiceInbox: 'No voice inbox available.',
  loadingRecentCalls: 'Loading recent calls...',
  noRecentCalls: 'No recent calls.',
  startCall: 'Start call',
};

const route = useRoute();
const router = useRouter();
const store = useStore();
const callsStore = useCallsStore();
const whatsappCallSession = useWhatsappCallSession();
const { accountScopedRoute } = useAccount();

const isOpen = ref(false);
const phoneNumber = ref('');
const selectedCountryCode = ref('+39');
const selectedInboxId = ref(null);
const inputRef = ref(null);
const countrySearchRef = ref(null);
const countrySearch = ref('');
const isCountryPickerOpen = ref(false);
const recentCalls = ref([]);
const isFetchingCalls = ref(false);
const isStartingTwilioCall = ref(false);

const inboxesList = useMapGetter('inboxes/getInboxes');
const contactsUiFlags = useMapGetter('contacts/getUIFlags');
const voiceInboxes = computed(() =>
  (inboxesList.value || []).filter(isVoiceCallEnabled)
);
const selectedInbox = computed(() =>
  voiceInboxes.value.find(inbox => inbox.id === selectedInboxId.value)
);
const isInitiatingCall = computed(
  () =>
    contactsUiFlags.value?.isInitiatingCall ||
    isStartingTwilioCall.value ||
    whatsappCallSession.isInitiating.value
);
const hasCallInProgress = computed(
  () => callsStore.hasActiveCall || callsStore.hasIncomingCall
);
const sanitizedInput = computed(() => phoneNumber.value.replace(/[^\d+]/g, ''));
const normalizedPhoneNumber = computed(() => {
  const raw = sanitizedInput.value.trim();
  if (!raw) return '';
  if (raw.startsWith('+')) return `+${raw.slice(1).replace(/\D/g, '')}`;
  if (raw.startsWith('00')) return `+${raw.slice(2).replace(/\D/g, '')}`;
  return `${selectedCountryCode.value}${raw.replace(/\D/g, '')}`;
});
const isCallableNumber = computed(() =>
  /^\+[1-9]\d{1,14}$/.test(normalizedPhoneNumber.value)
);
const canStartCall = computed(
  () =>
    isCallableNumber.value &&
    selectedInbox.value &&
    !isInitiatingCall.value &&
    !hasCallInProgress.value
);
const panelPositionClass = computed(() =>
  props.isCollapsed
    ? 'ltr:left-[4.5rem] rtl:right-[4.5rem] bottom-[5.25rem]'
    : 'ltr:left-3 rtl:right-3 bottom-[5.25rem]'
);
const selectedCountry = computed(
  () =>
    COUNTRY_OPTIONS.find(
      country => country.code === selectedCountryCode.value
    ) || COUNTRY_OPTIONS[0]
);
const filteredCountries = computed(() => {
  const query = countrySearch.value.trim().toLowerCase();
  if (!query) return COUNTRY_OPTIONS;

  return COUNTRY_OPTIONS.filter(country =>
    [country.name, country.code, country.id].some(value =>
      value.toLowerCase().includes(query)
    )
  );
});

watch(
  voiceInboxes,
  inboxes => {
    if (!selectedInboxId.value && inboxes.length) {
      selectedInboxId.value = inboxes[0].id;
    }
  },
  { immediate: true }
);

const focusInput = () => nextTick(() => inputRef.value?.focus());

const fetchRecentCalls = async () => {
  isFetchingCalls.value = true;
  try {
    const { data } = await CallsAPI.get({ page: 1 });
    recentCalls.value = camelcaseKeys(data.payload || [], { deep: true }).slice(
      0,
      5
    );
  } catch (_) {
    recentCalls.value = [];
    useAlert('Could not load recent calls.');
  } finally {
    isFetchingCalls.value = false;
  }
};

const openDialer = async () => {
  await fetchRecentCalls();
  isOpen.value = true;
  focusInput();
};

const closeDialer = () => {
  isOpen.value = false;
  isCountryPickerOpen.value = false;
};

const toggleDialer = () => {
  if (isOpen.value) closeDialer();
  else openDialer();
};

const formatPhoneInput = event => {
  phoneNumber.value = event.target.value.replace(/[^\d+\s()-]/g, '');
};

const toggleCountryPicker = () => {
  isCountryPickerOpen.value = !isCountryPickerOpen.value;
  if (isCountryPickerOpen.value) {
    countrySearch.value = '';
    nextTick(() => countrySearchRef.value?.focus());
  }
};

const selectCountry = country => {
  selectedCountryCode.value = country.code;
  isCountryPickerOpen.value = false;
  focusInput();
};

const findContactByPhone = async phone => {
  const response = await ContactAPI.search(phone, 1);
  const contacts = response.data?.payload || [];
  return (
    contacts.find(
      contact => (contact.phone_number || contact.phoneNumber) === phone
    ) || contacts[0]
  );
};

const findOrCreateContact = async phone => {
  const existing = await findContactByPhone(phone);
  if (existing) return existing;

  try {
    return await store.dispatch('contacts/create', {
      name: phone,
      phone_number: phone,
      additional_attributes: { social_profiles: {} },
    });
  } catch (_) {
    const contact = await findContactByPhone(phone);
    if (contact) return contact;
    throw new Error('Could not create a contact for this phone number.');
  }
};

const navigateToConversation = conversationId => {
  const accountId = route.params.accountId;
  if (!conversationId || !accountId) return;
  router.push({
    path: frontendURL(conversationUrl({ accountId, id: conversationId })),
  });
};

const startWhatsappCall = async ({ contactId, inboxId }) => {
  const response = await whatsappCallSession.initiateOutboundCall({
    contactId,
    inboxId,
  });
  if (response?.status === VOICE_CALL_OUTBOUND_INIT_STATUS.LOCKED) return;

  const conversationId = response?.conversation_id;
  if (!response?.id) {
    useAlert(
      response?.status === VOICE_CALL_OUTBOUND_INIT_STATUS.PERMISSION_PENDING
        ? 'Call permission is already pending for this contact.'
        : 'Call permission request sent to this contact.'
    );
    navigateToConversation(conversationId);
    return;
  }

  callsStore.addCall({
    callSid: response.call_id,
    callId: response.id,
    conversationId,
    inboxId,
    callDirection: VOICE_CALL_DIRECTION.OUTBOUND,
    provider: VOICE_CALL_PROVIDERS.WHATSAPP,
  });
  useAlert('Call initiated.');
  navigateToConversation(conversationId);
};

const startTwilioCall = async ({ contactId, inboxId }) => {
  isStartingTwilioCall.value = true;
  try {
    const { data: response } = await CallsAPI.create({
      contact_id: contactId,
      inbox_id: inboxId,
      phone_number: normalizedPhoneNumber.value,
    });
    const { call_sid: callSid, conversation_id: conversationId } = response;
    callsStore.addCall({
      callSid,
      conversationId,
      inboxId,
      callDirection: VOICE_CALL_DIRECTION.OUTBOUND,
      provider: VOICE_CALL_PROVIDERS.TWILIO,
    });
    useAlert('Call initiated.');
    navigateToConversation(conversationId);
  } finally {
    isStartingTwilioCall.value = false;
  }
};

const startCall = async (number = normalizedPhoneNumber.value) => {
  if (!selectedInbox.value || hasCallInProgress.value) return;
  if (!/^\+[1-9]\d{1,14}$/.test(number)) {
    useAlert('Enter a valid phone number.');
    return;
  }

  try {
    const contact = await findOrCreateContact(number);
    const payload = { contactId: contact.id, inboxId: selectedInbox.value.id };
    if (
      getVoiceCallProvider(selectedInbox.value) ===
      VOICE_CALL_PROVIDERS.WHATSAPP
    ) {
      await startWhatsappCall(payload);
    } else {
      await startTwilioCall(payload);
    }
    phoneNumber.value = '';
    fetchRecentCalls();
  } catch (error) {
    useAlert(error?.message || 'Could not start this call.');
  }
};

const callRecent = call => {
  const number =
    call.direction === VOICE_CALL_DIRECTION.OUTBOUND
      ? call.toNumber || call.to_number
      : call.contact?.phoneNumber ||
        call.contact?.phone_number ||
        call.fromNumber ||
        call.from_number;
  if (!number) return;
  phoneNumber.value = number;
  startCall(number);
};

const recentContactLabel = call => {
  const number =
    call.direction === VOICE_CALL_DIRECTION.OUTBOUND
      ? call.toNumber || call.to_number
      : call.contact?.phoneNumber ||
        call.contact?.phone_number ||
        call.fromNumber ||
        call.from_number;
  const name = call.contact?.name;
  return name && name !== number ? name : number || 'Unknown';
};

const recentCallTime = call =>
  call.createdAt ? dynamicTimeStrict(call.createdAt) : '';

const onKeydown = event => {
  if (event.key !== 'Escape') return;
  if (isCountryPickerOpen.value) {
    isCountryPickerOpen.value = false;
    return;
  }
  closeDialer();
};

onMounted(() => {
  window.addEventListener('keydown', onKeydown);
});

onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKeydown);
});
</script>

<template>
  <div
    v-on-click-outside="[
      closeDialer,
      { ignore: ['[data-sidebar-dialer-trigger]'] },
    ]"
    class="relative w-full"
  >
    <button
      data-sidebar-dialer-trigger
      type="button"
      class="mx-auto mb-1 flex size-10 items-center justify-center rounded-lg text-n-slate-11 transition-colors hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
      :class="{ 'bg-n-alpha-2 text-n-brand': isOpen }"
      :title="TEXT.phoneTitle"
      :aria-label="TEXT.openPhoneDialer"
      :aria-expanded="isOpen"
      @click="toggleDialer"
    >
      <span class="i-lucide-phone size-5" />
    </button>

    <div
      v-if="isOpen"
      data-popover-content
      class="fixed z-[70] w-[316px] overflow-hidden rounded-md border border-n-weak bg-white shadow-xl dark:bg-n-solid-2"
      :class="panelPositionClass"
    >
      <div class="bg-[#123852] text-white">
        <div class="flex h-11 items-center justify-between px-4">
          <div class="relative min-w-0">
            <button
              type="button"
              class="flex h-8 max-w-[10.5rem] items-center gap-2 rounded px-1 text-left text-sm font-semibold hover:bg-white/10 focus-visible:outline focus-visible:outline-2 focus-visible:outline-white"
              :aria-label="TEXT.countryCode"
              :aria-expanded="isCountryPickerOpen"
              @click="toggleCountryPicker"
            >
              <span class="truncate">{{ selectedCountry.name }}</span>
              <span class="shrink-0 text-white/75">{{
                selectedCountry.code
              }}</span>
              <span
                class="i-lucide-chevron-down size-3 shrink-0 text-white/75"
              />
            </button>
            <div
              v-if="isCountryPickerOpen"
              class="absolute left-0 top-9 z-[80] w-[264px] overflow-hidden rounded-md border border-n-weak bg-white text-n-slate-12 shadow-xl dark:bg-n-solid-2 dark:text-n-slate-12"
            >
              <div
                class="flex h-10 items-center gap-2 border-b border-n-weak px-3"
              >
                <span class="i-lucide-search size-4 text-n-slate-10" />
                <input
                  ref="countrySearchRef"
                  v-model="countrySearch"
                  class="min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-n-slate-10"
                  :placeholder="TEXT.countrySearchPlaceholder"
                  autocomplete="off"
                />
                <button
                  type="button"
                  class="grid size-7 shrink-0 place-content-center rounded text-n-slate-10 hover:bg-n-alpha-1 hover:text-n-slate-12"
                  :title="TEXT.closeCountrySearch"
                  @click="isCountryPickerOpen = false"
                >
                  <span class="i-lucide-x size-4" />
                </button>
              </div>
              <div class="max-h-[240px] overflow-y-auto py-1">
                <button
                  v-for="country in filteredCountries"
                  :key="country.id"
                  type="button"
                  class="flex h-9 w-full items-center justify-between gap-3 px-3 text-left text-sm hover:bg-n-alpha-1"
                  @click="selectCountry(country)"
                >
                  <span class="min-w-0 truncate">{{ country.name }}</span>
                  <span class="shrink-0 text-n-slate-10">{{
                    country.code
                  }}</span>
                </button>
                <div
                  v-if="!filteredCountries.length"
                  class="px-3 py-6 text-center text-sm text-n-slate-10"
                >
                  {{ TEXT.noCountriesFound }}
                </div>
              </div>
            </div>
          </div>
        </div>
        <form
          class="flex h-14 items-center border-t border-white/5"
          @submit.prevent="startCall()"
        >
          <span class="i-lucide-search mx-4 size-5 text-[#6e8ba2]" />
          <input
            ref="inputRef"
            :value="phoneNumber"
            class="min-w-0 flex-1 bg-transparent pr-4 text-sm text-white outline-none placeholder:text-[#6e8ba2]"
            :placeholder="TEXT.inputPlaceholder"
            inputmode="tel"
            autocomplete="off"
            @input="formatPhoneInput"
          />
        </form>
      </div>

      <div
        class="flex h-16 items-center justify-between bg-n-slate-1 px-5 pt-4 dark:bg-n-solid-3"
      >
        <span
          class="border-b-2 border-n-brand px-1 leading-5 text-xs font-medium text-n-brand"
        >
          {{ TEXT.recentCalls }}
        </span>
        <RouterLink
          :to="accountScopedRoute('calls_dashboard_index')"
          class="text-xs font-medium leading-5 text-n-brand hover:underline"
          @click="closeDialer"
        >
          {{ TEXT.viewAll }}
        </RouterLink>
      </div>

      <div class="h-[260px] overflow-y-auto bg-white dark:bg-n-solid-2">
        <div
          v-if="isFetchingCalls"
          class="flex h-full items-center justify-center text-sm text-n-slate-11"
        >
          {{ TEXT.loadingRecentCalls }}
        </div>
        <div
          v-else-if="!recentCalls.length"
          class="flex h-full items-center justify-center text-sm text-n-slate-11"
        >
          {{ TEXT.noRecentCalls }}
        </div>
        <template v-else>
          <button
            v-for="call in recentCalls"
            :key="call.id"
            type="button"
            class="flex h-[52px] w-full items-center gap-3 border-b border-n-weak px-4 text-left transition-colors hover:bg-n-alpha-1 disabled:cursor-not-allowed disabled:opacity-60"
            :disabled="isInitiatingCall || hasCallInProgress"
            @click="callRecent(call)"
          >
            <span
              class="flex size-8 shrink-0 items-center justify-center rounded-full bg-[#8bd59a] text-white"
            >
              <span class="i-lucide-plus size-4" />
            </span>
            <span
              class="min-w-0 flex-1 truncate text-sm text-[#1f4961] dark:text-n-slate-12"
            >
              {{ recentContactLabel(call) }}
            </span>
            <span class="shrink-0 text-xs text-n-slate-10">
              {{ recentCallTime(call) }}
            </span>
          </button>
        </template>
      </div>

      <div
        class="flex h-14 items-center justify-center border-t border-n-weak bg-n-slate-1 px-4 dark:bg-n-solid-3"
      >
        <button
          type="button"
          class="grid size-10 place-content-center rounded-full bg-[#22c55e] text-white shadow-sm transition-colors hover:bg-[#16a34a] disabled:cursor-not-allowed disabled:bg-n-slate-7 disabled:text-n-slate-10"
          :disabled="!canStartCall"
          :title="TEXT.startCall"
          @click="startCall()"
        >
          <span class="i-lucide-phone-call size-5" />
        </button>
      </div>
    </div>
  </div>
</template>

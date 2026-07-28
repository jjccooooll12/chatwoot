<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store.js';
import { useRouter, useRoute } from 'vue-router';
import { useTrack } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useI18n } from 'vue-i18n';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { generateURLParams, parseURLParams } from '../helpers/searchHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
  CONTACT_PERMISSIONS,
} from 'dashboard/constants/permissions.js';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { CONVERSATION_EVENTS } from '../../../helper/AnalyticsHelper/events';

import Policy from 'dashboard/components/policy.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SearchHeader from './SearchHeader.vue';
import SearchTabs from './SearchTabs.vue';
import SearchResultConversationsList from './SearchResultConversationsList.vue';
import SearchResultContactsList from './SearchResultContactsList.vue';

const router = useRouter();
const route = useRoute();
const store = useStore();
const { currentAccount } = useAccount();
const { t } = useI18n();

const PER_PAGE = 15; // Results per page
const DEFAULT_TAB = 'contacts';
const selectedTab = ref(route.params.tab || DEFAULT_TAB);
const query = ref(route.query.q || '');
const pages = ref({
  contacts: 1,
  conversations: 1,
});

const contactRecords = useMapGetter('conversationSearch/getContactRecords');
const conversationRecords = useMapGetter(
  'conversationSearch/getConversationRecords'
);
const uiFlags = useMapGetter('conversationSearch/getUIFlags');

const addTypeToRecords = (records, type) =>
  records.value.map(item => ({ ...useCamelCase(item, { deep: true }), type }));

const contacts = computed(() => addTypeToRecords(contactRecords, 'contact'));
const conversations = computed(() =>
  addTypeToRecords(conversationRecords, 'conversation')
);

const filterContacts = computed(() => selectedTab.value === 'contacts');
const filterConversations = computed(
  () => selectedTab.value === 'conversations'
);

const { shouldShow, isFeatureFlagEnabled } = usePolicy();

// Contacts first, Conversations second — a contact/email search lands on
// the matching contact by default, with Conversations one click away.
const TABS_CONFIG = {
  contacts: {
    permissions: [...ROLES, CONTACT_PERMISSIONS],
    count: () => contacts.value.length,
  },
  conversations: {
    permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
    count: () => conversations.value.length,
  },
};

const tabs = computed(() => {
  return Object.entries(TABS_CONFIG)
    .map(([key, config]) => ({
      key,
      name: t(`SEARCH.TABS.${key.toUpperCase()}`),
      count: config.count(),
      showBadge: true,
      permissions: config.permissions,
    }))
    .filter(config => shouldShow(config.featureFlag, config.permissions, null));
});

const activeTabIndex = computed(() => {
  const index = tabs.value.findIndex(tab => tab.key === selectedTab.value);
  return index >= 0 ? index : 0;
});

const isFetchingAny = computed(() => {
  const { contact, conversation, isFetching } = uiFlags.value;
  return isFetching || contact.isFetching || conversation.isFetching;
});

// Each SearchResultSection already renders its own "nothing found" state
// (see SearchResultSection.vue's `empty` prop), so the only thing the page
// needs to decide is whether a search has been run at all.
const showResultsSection = computed(() => !!query.value);

const showLoadMore = computed(() => {
  if (!query.value || isFetchingAny.value) return false;

  const records = {
    contacts: contacts.value,
    conversations: conversations.value,
  }[selectedTab.value];

  return (
    records?.length > 0 &&
    records.length === pages.value[selectedTab.value] * PER_PAGE
  );
});

const filters = ref({
  from: null,
  in: null,
  dateRange: { type: null, from: null, to: null },
});

const clearSearchResult = () => {
  pages.value = { contacts: 1, conversations: 1 };
  store.dispatch('conversationSearch/clearSearchResults');
};

const buildSearchPayload = (basePayload = {}, searchType = 'message') => {
  const payload = { ...basePayload };

  // Only include filters if advanced search is enabled
  if (isFeatureFlagEnabled(FEATURE_FLAGS.ADVANCED_SEARCH)) {
    // Date filters apply to all search types
    if (filters.value.dateRange.from) {
      payload.since = filters.value.dateRange.from;
    }
    if (filters.value.dateRange.to) {
      payload.until = filters.value.dateRange.to;
    }

    // Only messages support 'from' and 'inboxId' filters
    if (searchType === 'message') {
      if (filters.value.from) payload.from = filters.value.from;
      if (filters.value.in) payload.inboxId = filters.value.in;
    }
  }

  return payload;
};

const updateURL = () => {
  const params = {
    accountId: route.params.accountId,
    ...(selectedTab.value !== DEFAULT_TAB && { tab: selectedTab.value }),
  };

  const queryParams = {
    ...(query.value?.trim() && { q: query.value.trim() }),
    ...generateURLParams(
      filters.value,
      isFeatureFlagEnabled(FEATURE_FLAGS.ADVANCED_SEARCH)
    ),
  };

  router.replace({ name: 'search', params, query: queryParams });
};

const onSearch = q => {
  query.value = q;
  clearSearchResult();
  updateURL();
  if (!q) return;
  useTrack(CONVERSATION_EVENTS.SEARCH_CONVERSATION);

  const searchPayload = buildSearchPayload({ q, page: 1 });
  store.dispatch('conversationSearch/fullSearch', searchPayload);
};

const onFilterChange = () => {
  onSearch(query.value);
};

const onBack = () => {
  if (window.history.length > 2) {
    router.go(-1);
  } else {
    router.push({ name: 'home' });
  }
  clearSearchResult();
};

const loadMore = () => {
  const SEARCH_ACTIONS = {
    contacts: 'conversationSearch/contactSearch',
    conversations: 'conversationSearch/conversationSearch',
  };

  if (uiFlags.value.isFetching) return;

  const tab = selectedTab.value;
  pages.value[tab] += 1;

  const payload = buildSearchPayload(
    { q: query.value, page: pages.value[tab] },
    tab
  );

  store.dispatch(SEARCH_ACTIONS[tab], payload);
};

const onTabChange = tab => {
  selectedTab.value = tab;
  updateURL();
};

onMounted(() => {
  store.dispatch('conversationSearch/clearSearchResults');
  store.dispatch('agents/get');
});

// Wait for the account before restoring URL filters: the ADVANCED_SEARCH flag
// derives from account.features (loaded async), and reading it too early strips
// the filter params from the URL. `immediate` covers the already-loaded case.
watch(
  () => currentAccount.value?.id,
  id => {
    if (!id) return;
    filters.value = parseURLParams(
      route.query,
      isFeatureFlagEnabled(FEATURE_FLAGS.ADVANCED_SEARCH)
    );
    if (route.query.q) {
      onSearch(route.query.q);
    }
  },
  { immediate: true }
);

onUnmounted(() => {
  query.value = '';
  store.dispatch('conversationSearch/clearSearchResults');
});
</script>

<template>
  <div class="flex flex-col w-full h-full bg-n-surface-1">
    <div class="flex w-full p-4">
      <NextButton
        :label="t('GENERAL_SETTINGS.BACK')"
        icon="i-lucide-chevron-left"
        faded
        primary
        sm
        @click="onBack"
      />
    </div>
    <section class="flex flex-col flex-grow w-full h-full overflow-hidden">
      <div class="w-full max-w-5xl mx-auto z-30">
        <div class="flex flex-col w-full px-4">
          <SearchHeader
            v-model:filters="filters"
            :initial-query="query"
            @search="onSearch"
            @filter-change="onFilterChange"
          />
          <SearchTabs
            v-if="query"
            :tabs="tabs"
            :selected-tab="activeTabIndex"
            @tab-change="onTabChange"
          />
        </div>
      </div>
      <div class="flex-grow w-full h-full overflow-y-auto">
        <div class="w-full max-w-5xl mx-auto px-4 pb-6">
          <div v-if="showResultsSection">
            <Policy
              :permissions="[...ROLES, CONTACT_PERMISSIONS]"
              class="flex flex-col justify-center"
            >
              <SearchResultContactsList
                v-if="filterContacts"
                :is-fetching="uiFlags.contact.isFetching"
                :contacts="contacts"
                :query="query"
                :show-title="false"
                class="mt-0.5"
              />
            </Policy>

            <Policy
              :permissions="[...ROLES, ...CONVERSATION_PERMISSIONS]"
              class="flex flex-col justify-center"
            >
              <SearchResultConversationsList
                v-if="filterConversations"
                :is-fetching="uiFlags.conversation.isFetching"
                :conversations="conversations"
                :query="query"
                :show-title="false"
                class="mt-0.5"
              />
            </Policy>

            <div v-if="showLoadMore" class="flex justify-center mt-3 mb-6">
              <NextButton
                :label="t(`SEARCH.LOAD_MORE`)"
                icon="i-lucide-cloud-download"
                slate
                sm
                faded
                @click="loadMore"
              />
            </div>
          </div>
          <div
            v-else-if="!query"
            class="flex flex-col items-center justify-center px-4 py-6 mt-8 text-center rounded-md"
          >
            <p class="text-center margin-bottom-0">
              <fluent-icon icon="search" size="24px" class="text-n-slate-11" />
            </p>
            <p class="m-2 text-center text-n-slate-11">
              {{ t('SEARCH.EMPTY_STATE_DEFAULT') }}
            </p>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>

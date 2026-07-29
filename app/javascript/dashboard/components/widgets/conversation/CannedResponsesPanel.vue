<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import AddCanned from 'dashboard/routes/dashboard/settings/canned/AddCanned.vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { frontendURL } from 'dashboard/helper/URLHelper';

const emit = defineEmits(['close']);

const RECENT_KEY = 'chatwoot_canned_responses_recent';
const STARRED_KEY = 'chatwoot_canned_responses_starred';
const BANNER_KEY = 'chatwoot_canned_responses_banner_dismissed';
const MAX_RECENT = 5;

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();
const route = useRoute();
const { getPlainText } = useMessageFormatter();

const manageUrl = computed(() =>
  frontendURL(
    `accounts/${route.params.accountId}/settings/canned-response/list`
  )
);

const searchQuery = ref('');
const folderFilter = ref('all');
const visibilityFilter = ref('all');
const starredOnly = ref(false);
const expandedId = ref(null);
const showCreateModal = ref(false);
const bannerDismissed = ref(localStorage.getItem(BANNER_KEY) === '1');
const recentCodes = ref(JSON.parse(localStorage.getItem(RECENT_KEY) || '[]'));
const starredCodes = ref(JSON.parse(localStorage.getItem(STARRED_KEY) || '[]'));

const records = computed(() => getters.getCannedResponses.value);
const folders = computed(() => getters.getCannedResponseFolders.value);

const visibilityLabel = item =>
  item.visibility === 'global'
    ? t('CANNED_MGMT.LIST.VISIBILITY.SHARED')
    : t('CANNED_MGMT.LIST.VISIBILITY.PERSONAL');

const folderName = item => {
  if (!item.folder_id) return t('CANNED_MGMT.LIST.FOLDER_FILTER.UNCATEGORIZED');
  const folder = folders.value.find(f => f.id === item.folder_id);
  return folder
    ? folder.name
    : t('CANNED_MGMT.LIST.FOLDER_FILTER.UNCATEGORIZED');
};

const visibilityFilterOptions = computed(() => [
  { value: 'all', label: t('CANNED_MGMT.LIST.VISIBILITY.ALL') },
  { value: 'personal', label: t('CANNED_MGMT.LIST.VISIBILITY.PERSONAL') },
  { value: 'global', label: t('CANNED_MGMT.LIST.VISIBILITY.SHARED') },
]);

const isStarred = item => starredCodes.value.includes(item.short_code);

const toggleStar = item => {
  starredCodes.value = isStarred(item)
    ? starredCodes.value.filter(code => code !== item.short_code)
    : [...starredCodes.value, item.short_code];
  localStorage.setItem(STARRED_KEY, JSON.stringify(starredCodes.value));
};

const filteredRecords = computed(() => {
  let list = records.value;
  if (folderFilter.value === 'uncategorized') {
    list = list.filter(item => !item.folder_id);
  } else if (folderFilter.value !== 'all') {
    list = list.filter(item => String(item.folder_id) === folderFilter.value);
  }
  if (visibilityFilter.value !== 'all') {
    list = list.filter(item => item.visibility === visibilityFilter.value);
  }
  if (starredOnly.value) {
    list = list.filter(item => isStarred(item));
  }
  return list;
});

const isDefaultView = computed(
  () =>
    !searchQuery.value.trim() &&
    folderFilter.value === 'all' &&
    visibilityFilter.value === 'all' &&
    !starredOnly.value
);

const recentlyUsedItems = computed(() =>
  recentCodes.value
    .map(code => records.value.find(item => item.short_code === code))
    .filter(Boolean)
    .slice(0, MAX_RECENT)
);

const showRecentSection = computed(
  () => isDefaultView.value && recentlyUsedItems.value.length > 0
);

const primarySectionLabel = computed(() => {
  if (starredOnly.value) {
    return t('CONVERSATION.REPLYBOX.CANNED_PANEL.STARRED');
  }
  if (searchQuery.value.trim()) {
    return t('CONVERSATION.REPLYBOX.CANNED_PANEL.SEARCH_RESULTS');
  }
  return t('CONVERSATION.REPLYBOX.CANNED_PANEL.ALL_RESPONSES');
});

const sections = computed(() => {
  const result = [];
  if (showRecentSection.value) {
    result.push({
      key: 'recent',
      label: t('CONVERSATION.REPLYBOX.CANNED_PANEL.RECENTLY_USED'),
      items: recentlyUsedItems.value,
    });
  }
  result.push({
    key: 'primary',
    label: primarySectionLabel.value,
    items: filteredRecords.value,
  });
  return result;
});

const fetchResponses = () => {
  store.dispatch('getCannedResponse', { searchKey: searchQuery.value });
};

onMounted(() => {
  fetchResponses();
  store.dispatch('getCannedResponseFolders');
});
watch(searchQuery, fetchResponses);

const toggleExpand = item => {
  expandedId.value = expandedId.value === item.id ? null : item.id;
};

const selectItem = item => {
  recentCodes.value = [
    item.short_code,
    ...recentCodes.value.filter(code => code !== item.short_code),
  ].slice(0, MAX_RECENT);
  localStorage.setItem(RECENT_KEY, JSON.stringify(recentCodes.value));
  emitter.emit(BUS_EVENTS.INSERT_INTO_RICH_EDITOR, item.content);
  emit('close');
};

const dismissBanner = () => {
  bannerDismissed.value = true;
  localStorage.setItem(BANNER_KEY, '1');
};

const openCreateModal = () => {
  showCreateModal.value = true;
};
const hideCreateModal = () => {
  showCreateModal.value = false;
};
</script>

<template>
  <aside
    class="hidden w-[400px] shrink-0 flex-col overflow-hidden border-l border-fd-border bg-fd-surface xl:flex"
  >
    <div
      class="flex items-center justify-between gap-2 border-b border-fd-border px-3 py-3"
    >
      <div class="flex min-w-0 items-center gap-2">
        <Icon icon="i-lucide-bookmark" class="size-4 shrink-0 text-fd-text" />
        <span class="truncate text-sm font-semibold text-fd-text">
          {{ t('CONVERSATION.REPLYBOX.CANNED_RESPONSES_HEADER') }}
        </span>
        <button
          type="button"
          class="shrink-0 text-xs font-medium text-fd-primary hover:underline"
          @click="openCreateModal"
        >
          {{ t('CONVERSATION.REPLYBOX.CANNED_RESPONSES_CREATE_NEW') }}
        </button>
      </div>
      <button
        type="button"
        :aria-label="t('CONVERSATION.REPLYBOX.CANNED_PANEL.CLOSE')"
        class="shrink-0 rounded p-1 text-fd-muted hover:bg-n-slate-3 hover:text-fd-text"
        @click="emit('close')"
      >
        <Icon icon="i-lucide-x" class="size-4" />
      </button>
    </div>

    <div class="border-b border-fd-border px-3 py-2.5">
      <div
        class="flex items-center rounded-md border border-fd-border bg-fd-background focus-within:border-fd-primary"
      >
        <div class="relative min-w-0 flex-1">
          <Icon
            icon="i-lucide-search"
            class="pointer-events-none absolute left-2 top-1/2 size-3.5 -translate-y-1/2 text-fd-muted"
          />
          <input
            v-model="searchQuery"
            type="text"
            :placeholder="
              t('CONVERSATION.REPLYBOX.CANNED_PANEL.SEARCH_PLACEHOLDER')
            "
            class="reset-base w-full border-0 bg-transparent py-1.5 pl-7 pr-2 text-xs text-fd-text placeholder:text-fd-muted focus:outline-none"
          />
        </div>
        <div class="relative shrink-0 border-l border-fd-border">
          <Icon
            icon="i-lucide-folder"
            class="pointer-events-none absolute left-2 top-1/2 size-3.5 -translate-y-1/2 text-fd-muted"
          />
          <select
            v-model="folderFilter"
            class="reset-base appearance-none border-0 bg-transparent py-1.5 pl-7 pr-6 text-xs text-fd-text focus:outline-none"
          >
            <option value="all">
              {{ t('CANNED_MGMT.LIST.FOLDER_FILTER.ALL') }}
            </option>
            <option value="uncategorized">
              {{ t('CANNED_MGMT.LIST.FOLDER_FILTER.UNCATEGORIZED') }}
            </option>
            <option
              v-for="folder in folders"
              :key="folder.id"
              :value="String(folder.id)"
            >
              {{ folder.name }}
            </option>
          </select>
          <Icon
            icon="i-lucide-chevron-down"
            class="pointer-events-none absolute right-1.5 top-1/2 size-3.5 -translate-y-1/2 text-fd-muted"
          />
        </div>
      </div>

      <div class="mt-2 flex items-center justify-between gap-2">
        <div class="flex items-center gap-1 rounded-md bg-n-slate-2 p-0.5">
          <button
            v-for="option in visibilityFilterOptions"
            :key="option.value"
            type="button"
            class="rounded px-2 py-1 text-xs font-medium transition-colors"
            :class="
              visibilityFilter === option.value
                ? 'bg-fd-surface text-fd-text shadow-sm'
                : 'text-fd-muted hover:text-fd-text'
            "
            @click="visibilityFilter = option.value"
          >
            {{ option.label }}
          </button>
        </div>
        <button
          v-tooltip.top="t('CONVERSATION.REPLYBOX.CANNED_PANEL.STARRED_ONLY')"
          type="button"
          :aria-label="t('CONVERSATION.REPLYBOX.CANNED_PANEL.STARRED_ONLY')"
          class="shrink-0 rounded p-1.5 transition-colors"
          :class="
            starredOnly
              ? 'bg-fd-amber/10 text-fd-amber'
              : 'text-fd-muted hover:bg-n-slate-2 hover:text-fd-text'
          "
          @click="starredOnly = !starredOnly"
        >
          <Icon
            :icon="starredOnly ? 'i-ph-star-fill' : 'i-ph-star'"
            class="size-4"
          />
        </button>
      </div>
    </div>

    <div
      v-if="!bannerDismissed"
      class="mx-3 mt-3 flex items-start gap-2 rounded-md border border-fd-primary/20 bg-fd-primary/5 px-2.5 py-2 text-xs text-fd-text"
    >
      <Icon
        icon="i-lucide-info"
        class="mt-0.5 size-3.5 shrink-0 text-fd-primary"
      />
      <div class="flex-1">
        <p class="m-0">
          {{ t('CONVERSATION.REPLYBOX.CANNED_PANEL.BANNER_TEXT') }}
        </p>
        <a :href="manageUrl" class="text-fd-primary hover:underline">
          {{ t('CONVERSATION.REPLYBOX.CANNED_PANEL.LEARN_MORE') }}
        </a>
      </div>
      <button
        type="button"
        class="shrink-0 text-fd-muted hover:text-fd-text"
        @click="dismissBanner"
      >
        <Icon icon="i-lucide-x" class="size-3.5" />
      </button>
    </div>

    <div class="min-h-0 flex-1 overflow-y-auto px-3 py-3">
      <template v-for="section in sections" :key="section.key">
        <p
          class="mb-2 text-xxs font-semibold uppercase tracking-wide text-fd-muted"
          :class="{ 'mt-4': section.key !== sections[0].key }"
        >
          {{ section.label }}
        </p>
        <p v-if="!section.items.length" class="mb-2 text-xs text-fd-muted">
          {{ t('CONVERSATION.REPLYBOX.CANNED_PANEL.NO_RESULTS') }}
        </p>
        <ul v-else class="m-0 mb-2 flex list-none flex-col gap-2 p-0">
          <li
            v-for="item in section.items"
            :key="item.id"
            class="rounded-md border border-fd-border bg-fd-background transition-colors hover:border-fd-primary"
          >
            <div
              class="flex cursor-pointer items-start gap-2 px-2.5 py-2"
              @click="selectItem(item)"
            >
              <button
                type="button"
                class="mt-0.5 shrink-0 rounded p-0.5 text-fd-muted hover:bg-n-slate-3 hover:text-fd-text"
                @click.stop="toggleExpand(item)"
              >
                <Icon
                  :icon="
                    expandedId === item.id
                      ? 'i-lucide-chevron-down'
                      : 'i-lucide-chevron-right'
                  "
                  class="size-3.5"
                />
              </button>
              <div class="min-w-0 flex-1">
                <p class="m-0 truncate text-sm font-medium text-fd-text">
                  {{ item.short_code }}
                </p>
                <p
                  v-if="expandedId === item.id"
                  class="m-0 mt-1 line-clamp-4 text-xs text-fd-muted"
                >
                  {{ getPlainText(item.content) }}
                </p>
                <div class="mt-1 flex items-center gap-2 text-xs text-fd-muted">
                  <span class="flex items-center gap-1">
                    <Icon icon="i-lucide-folder" class="size-3" />
                    {{ folderName(item) }}
                  </span>
                  <span>{{ visibilityLabel(item) }}</span>
                </div>
              </div>
              <button
                type="button"
                class="mt-0.5 shrink-0 rounded p-0.5"
                :class="
                  isStarred(item)
                    ? 'text-fd-amber'
                    : 'text-fd-muted hover:bg-n-slate-3 hover:text-fd-text'
                "
                @click.stop="toggleStar(item)"
              >
                <Icon
                  :icon="isStarred(item) ? 'i-ph-star-fill' : 'i-ph-star'"
                  class="size-3.5"
                />
              </button>
            </div>
          </li>
        </ul>
      </template>
    </div>

    <woot-modal v-model:show="showCreateModal" :on-close="hideCreateModal">
      <AddCanned :on-close="hideCreateModal" />
    </woot-modal>
  </aside>
</template>

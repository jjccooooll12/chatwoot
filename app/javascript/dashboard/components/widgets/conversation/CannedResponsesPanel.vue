<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import AddCanned from 'dashboard/routes/dashboard/settings/canned/AddCanned.vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

const emit = defineEmits(['close']);

const RECENT_KEY = 'chatwoot_canned_responses_recent';
const BANNER_KEY = 'chatwoot_canned_responses_banner_dismissed';
const MAX_RECENT = 5;

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();
const { getPlainText } = useMessageFormatter();

const searchQuery = ref('');
const folderFilter = ref('all');
const expandedId = ref(null);
const showCreateModal = ref(false);
const bannerDismissed = ref(localStorage.getItem(BANNER_KEY) === '1');
const recentCodes = ref(JSON.parse(localStorage.getItem(RECENT_KEY) || '[]'));

const records = computed(() => getters.getCannedResponses.value);

const folderLabel = computed(() => ({
  all: t('CONVERSATION.REPLYBOX.CANNED_PANEL.ALL_FOLDERS'),
  personal: t('CONVERSATION.REPLYBOX.CANNED_PANEL.PERSONAL_FOLDER'),
  global: t('CONVERSATION.REPLYBOX.CANNED_PANEL.SHARED_FOLDER'),
}));

const filteredRecords = computed(() => {
  if (folderFilter.value === 'all') return records.value;
  return records.value.filter(item => item.visibility === folderFilter.value);
});

const recentlyUsedItems = computed(() =>
  recentCodes.value
    .map(code => records.value.find(item => item.short_code === code))
    .filter(Boolean)
    .slice(0, MAX_RECENT)
);

const isShowingRecent = computed(
  () =>
    !searchQuery.value.trim() &&
    folderFilter.value === 'all' &&
    recentlyUsedItems.value.length > 0
);

const listItems = computed(() =>
  isShowingRecent.value ? recentlyUsedItems.value : filteredRecords.value
);

const sectionLabel = computed(() => {
  if (isShowingRecent.value) {
    return t('CONVERSATION.REPLYBOX.CANNED_PANEL.RECENTLY_USED');
  }
  if (searchQuery.value.trim()) {
    return t('CONVERSATION.REPLYBOX.CANNED_PANEL.SEARCH_RESULTS');
  }
  return t('CONVERSATION.REPLYBOX.CANNED_PANEL.ALL_RESPONSES');
});

const fetchResponses = () => {
  store.dispatch('getCannedResponse', { searchKey: searchQuery.value });
};

onMounted(fetchResponses);
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
        <Icon
          icon="i-lucide-book-open"
          class="size-4 shrink-0 text-fd-primary"
        />
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

    <div class="flex items-center gap-2 border-b border-fd-border px-3 py-2.5">
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
          class="reset-base w-full rounded-md border border-fd-border bg-fd-background py-1.5 pl-7 pr-2 text-xs text-fd-text placeholder:text-fd-muted focus:border-fd-primary focus:outline-none"
        />
      </div>
      <div class="relative shrink-0">
        <select
          v-model="folderFilter"
          class="reset-base appearance-none rounded-md border border-fd-border bg-fd-background py-1.5 pl-2 pr-6 text-xs text-fd-text focus:border-fd-primary focus:outline-none"
        >
          <option value="all">{{ folderLabel.all }}</option>
          <option value="personal">{{ folderLabel.personal }}</option>
          <option value="global">{{ folderLabel.global }}</option>
        </select>
        <Icon
          icon="i-lucide-chevron-down"
          class="pointer-events-none absolute right-1.5 top-1/2 size-3.5 -translate-y-1/2 text-fd-muted"
        />
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
      <span class="flex-1">
        {{ t('CONVERSATION.REPLYBOX.CANNED_PANEL.BANNER_TEXT') }}
      </span>
      <button
        type="button"
        class="shrink-0 text-fd-muted hover:text-fd-text"
        @click="dismissBanner"
      >
        <Icon icon="i-lucide-x" class="size-3.5" />
      </button>
    </div>

    <div class="min-h-0 flex-1 overflow-y-auto px-3 py-3">
      <p
        class="mb-2 text-xxs font-semibold uppercase tracking-wide text-fd-muted"
      >
        {{ sectionLabel }}
      </p>
      <p v-if="!listItems.length" class="text-xs text-fd-muted">
        {{ t('CONVERSATION.REPLYBOX.CANNED_PANEL.NO_RESULTS') }}
      </p>
      <ul v-else class="m-0 flex list-none flex-col gap-2 p-0">
        <li
          v-for="item in listItems"
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
              <div class="mt-1 flex items-center gap-1 text-xs text-fd-muted">
                <Icon icon="i-lucide-folder" class="size-3" />
                {{
                  item.visibility === 'global'
                    ? folderLabel.global
                    : folderLabel.personal
                }}
              </div>
            </div>
          </div>
        </li>
      </ul>
    </div>

    <woot-modal v-model:show="showCreateModal" :on-close="hideCreateModal">
      <AddCanned :on-close="hideCreateModal" />
    </woot-modal>
  </aside>
</template>

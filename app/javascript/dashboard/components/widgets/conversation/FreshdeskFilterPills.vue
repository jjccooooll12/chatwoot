<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  // [{ key, label, dot? (tailwind bg-* class), badge? (count shown in the
  // add-dropdown only) }]
  items: { type: Array, required: true },
  activeKeys: { type: Array, required: true },
});

const emit = defineEmits(['toggle']);
const { t } = useI18n();

const open = ref(false);

const activeItems = computed(() =>
  props.items.filter(item => props.activeKeys.includes(item.key))
);
const addableItems = computed(() =>
  props.items.filter(item => !props.activeKeys.includes(item.key))
);

const remove = key => emit('toggle', key);
const add = key => {
  emit('toggle', key);
  if (addableItems.value.length <= 1) {
    open.value = false;
  }
};
</script>

<template>
  <div class="flex flex-wrap items-center gap-1.5 px-2">
    <span v-if="!activeItems.length" class="text-xs italic text-fd-muted">
      {{ t('CHAT_LIST.FRESHDESK_PANEL.NO_FILTER') }}
    </span>
    <span
      v-for="item in activeItems"
      :key="item.key"
      class="inline-flex items-center gap-1 rounded-full bg-fd-primary/10 py-1 pl-2 pr-1 text-xs font-medium text-fd-primary"
    >
      <span
        v-if="item.dot"
        class="size-1.5 shrink-0 rounded-full"
        :class="item.dot"
      />
      <span class="truncate">{{ item.label }}</span>
      <button
        type="button"
        class="grid size-3.5 shrink-0 place-content-center rounded-full text-fd-primary/70 hover:bg-fd-primary/20 hover:text-fd-primary"
        :title="t('CHAT_LIST.FRESHDESK_PANEL.REMOVE_FILTER')"
        @click="remove(item.key)"
      >
        <span class="i-lucide-x size-2.5" />
      </button>
    </span>

    <div v-if="addableItems.length" class="relative">
      <button
        type="button"
        class="grid size-6 place-content-center rounded-full border border-dashed border-fd-border text-fd-muted hover:border-fd-primary hover:text-fd-primary"
        :title="t('CHAT_LIST.FRESHDESK_PANEL.ADD_FILTER')"
        @click="open = !open"
      >
        <span class="i-lucide-plus size-3.5" />
      </button>
      <template v-if="open">
        <button
          type="button"
          tabindex="-1"
          class="fixed inset-0 z-40 cursor-default"
          @click="open = false"
        />
        <ul
          class="absolute left-0 top-7 z-50 m-0 min-w-[9rem] list-none rounded-md border border-fd-border bg-fd-surface p-1 shadow-lg"
        >
          <li v-for="item in addableItems" :key="item.key">
            <button
              type="button"
              class="flex w-full items-center gap-2 rounded px-2 py-1.5 text-left text-xs text-fd-text hover:bg-n-slate-3"
              @click="add(item.key)"
            >
              <span
                v-if="item.dot"
                class="size-2 shrink-0 rounded-full"
                :class="item.dot"
              />
              <span class="flex-1 truncate">{{ item.label }}</span>
              <span
                v-if="item.badge !== undefined"
                class="shrink-0 rounded-md bg-fd-background px-1.5 py-0.5 text-xxs font-medium text-fd-muted"
              >
                {{ item.badge }}
              </span>
            </button>
          </li>
        </ul>
      </template>
    </div>
  </div>
</template>

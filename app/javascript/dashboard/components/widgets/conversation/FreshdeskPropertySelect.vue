<script setup>
import { computed, ref } from 'vue';

// Custom dropdown for the ticket properties panel. Native <select> popups are
// drawn by the browser and ignore `cursor`, so every property uses this
// instead to get the same pointer + hover row as the rest of the UI.
const props = defineProps({
  modelValue: {
    type: [String, Number],
    default: '',
  },
  // [{ value, label, dotClass? }] — dotClass renders a colored square.
  options: {
    type: Array,
    required: true,
  },
});

const emit = defineEmits(['update:modelValue']);

const isOpen = ref(false);

const selected = computed(
  () =>
    props.options.find(
      option => String(option.value) === String(props.modelValue)
    ) || props.options[0]
);

const dotClass = option => ['size-2.5 shrink-0 rounded-sm', option.dotClass];

const select = option => {
  isOpen.value = false;
  if (String(option.value) === String(props.modelValue)) return;
  emit('update:modelValue', option.value);
};
</script>

<template>
  <div class="relative" @keydown.esc="isOpen = false">
    <button
      type="button"
      class="flex h-8 w-full cursor-pointer items-center gap-2 rounded-md border border-fd-primary/40 bg-fd-surface px-2 text-xs text-fd-text outline-none focus:border-fd-primary"
      :aria-expanded="isOpen"
      aria-haspopup="listbox"
      @click="isOpen = !isOpen"
    >
      <span v-if="selected?.dotClass" :class="dotClass(selected)" />
      <span class="truncate">{{ selected?.label }}</span>
      <span
        class="i-lucide-chevron-down size-3.5 shrink-0 text-fd-muted ltr:ml-auto rtl:mr-auto"
      />
    </button>
    <template v-if="isOpen">
      <button
        type="button"
        tabindex="-1"
        class="fixed inset-0 z-40 cursor-default"
        @click="isOpen = false"
      />
      <ul
        role="listbox"
        class="absolute inset-x-0 top-9 z-50 m-0 max-h-64 list-none overflow-y-auto rounded-md border border-fd-border bg-fd-surface p-1 shadow-lg"
      >
        <li
          v-for="option in options"
          :key="option.value"
          role="option"
          :aria-selected="String(option.value) === String(modelValue)"
        >
          <button
            type="button"
            class="flex w-full cursor-pointer items-center gap-2 rounded px-2 py-1.5 text-left text-xs text-fd-text hover:bg-n-slate-3"
            @click="select(option)"
          >
            <span v-if="option.dotClass" :class="dotClass(option)" />
            <span class="truncate">{{ option.label }}</span>
          </button>
        </li>
      </ul>
    </template>
  </div>
</template>

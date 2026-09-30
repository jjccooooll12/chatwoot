<script setup>
import { ref, computed, onMounted, onBeforeUnmount, useTemplateRef } from 'vue';
import { useEventListener } from '@vueuse/core';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

const props = defineProps({
  containerHeight: { type: Number, default: 0 },
});

const DEFAULT_HEIGHT = 360;
const MIN_HEIGHT = 80;
const RESET_DELAY_MS = 120;

const wrapperRef = useTemplateRef('wrapperRef');
const surroundingHeight = ref(0);
const editorHeight = ref(DEFAULT_HEIGHT);
const isResizing = ref(false);
const isSnapping = ref(false);
const startY = ref(0);
const startHeight = ref(0);
let resetTimeoutId = null;

const clamp = (val, min, max) => Math.min(Math.max(val, min), max);

// Height of everything around the writing area: the mail fields, the toolbar
// and the send row. Measured against the editor's own box rather than the
// requested height, so it stays right while the height transition is running
// and when the request has been clamped.
const measureSurroundingHeight = () => {
  const wrapper = wrapperRef.value;
  if (!wrapper) return;
  const editor = wrapper.querySelector('.ProseMirror-woot-style');
  surroundingHeight.value = Math.max(
    0,
    wrapper.offsetHeight - (editor?.offsetHeight ?? editorHeight.value)
  );
};

const isContainerReady = computed(() => props.containerHeight > 0);

const sizeBounds = computed(() => {
  const h = props.containerHeight;
  const s = surroundingHeight.value;
  // The composer is allowed the whole thread area — the conversation is read by
  // scrolling up past it, so no strip of messages is held back here.
  const max = Math.max(MIN_HEIGHT, h - s);
  return {
    min: MIN_HEIGHT,
    max: isContainerReady.value ? max : DEFAULT_HEIGHT,
    default: clamp(DEFAULT_HEIGHT, MIN_HEIGHT, max),
  };
});

const clampToBounds = val =>
  clamp(val, sizeBounds.value.min, sizeBounds.value.max);

const clearDragStyles = () => {
  Object.assign(document.body.style, { cursor: '', userSelect: '' });
};

const getClientY = e => (e.touches ? e.touches[0].clientY : e.clientY);

const onResizeStart = event => {
  editorHeight.value = clampToBounds(editorHeight.value);
  measureSurroundingHeight();
  isResizing.value = true;
  startY.value = getClientY(event);
  startHeight.value = clampToBounds(editorHeight.value);
  editorHeight.value = startHeight.value;
  Object.assign(document.body.style, {
    cursor: 'row-resize',
    userSelect: 'none',
  });
};

const onResizeMove = event => {
  if (!isResizing.value) return;
  if (event.touches) event.preventDefault();
  editorHeight.value = clampToBounds(
    startHeight.value + startY.value - getClientY(event)
  );
};

const onResizeEnd = () => {
  if (!isResizing.value) return;
  isResizing.value = false;
  clearDragStyles();
};

const resetEditorHeight = () => {
  editorHeight.value = sizeBounds.value.default;
};

// Freshdesk: opening the composer sizes the writing area from a measurement
// only the conversation view can take — it can see the whole composer and where
// the panel scrolls to. So the height arrives already worked out; the drag
// bounds below deliberately do not clamp it. It is applied in one step, because
// animating it would mean scrolling to a target that is still moving.
const setEditorHeight = height => {
  isSnapping.value = true;
  measureSurroundingHeight();
  editorHeight.value = Math.max(MIN_HEIGHT, Math.round(height));
  requestAnimationFrame(() => {
    isSnapping.value = false;
  });
};

const toggleEditorExpand = () => {
  editorHeight.value = clampToBounds(editorHeight.value);
  measureSurroundingHeight();
  const { max, default: defaultHeight } = sizeBounds.value;
  const isExpanded = editorHeight.value > defaultHeight;
  editorHeight.value = isExpanded ? defaultHeight : max;
};

const handleMessageSent = () => {
  clearTimeout(resetTimeoutId);
  resetTimeoutId = setTimeout(resetEditorHeight, RESET_DELAY_MS);
};

onMounted(() => {
  emitter.on(BUS_EVENTS.MESSAGE_SENT, handleMessageSent);
});

onBeforeUnmount(() => {
  emitter.off(BUS_EVENTS.MESSAGE_SENT, handleMessageSent);
  clearTimeout(resetTimeoutId);
  if (isResizing.value) {
    isResizing.value = false;
    clearDragStyles();
  }
});

useEventListener(document, 'mousemove', onResizeMove);
useEventListener(document, 'mouseup', onResizeEnd);
useEventListener(document, 'touchmove', onResizeMove, { passive: false });
useEventListener(document, 'touchend', onResizeEnd);
useEventListener(document, 'touchcancel', onResizeEnd);
useEventListener(window, 'blur', onResizeEnd);

defineExpose({ toggleEditorExpand, resetEditorHeight, setEditorHeight });
</script>

<template>
  <div
    ref="wrapperRef"
    class="relative resizable-editor-wrapper"
    :style="{
      '--editor-height': editorHeight + 'px',
      '--editor-min-allowed': sizeBounds.min + 'px',
      '--editor-max-allowed': sizeBounds.max + 'px',
      '--editor-height-transition':
        isResizing || isSnapping ? 'none' : '180ms ease',
    }"
  >
    <div
      class="group absolute inset-x-0 top-0 z-10 flex h-4 cursor-row-resize select-none items-center justify-center bg-gradient-to-b from-transparent from-10% dark:to-n-surface-1/80 to-n-surface-1/90 backdrop-blur-[0.01875rem]"
      @mousedown="onResizeStart"
      @touchstart.prevent="onResizeStart"
      @dblclick="resetEditorHeight"
    >
      <div
        class="w-8 h-0.5 mt-1 rounded-full bg-n-slate-6 group-hover:bg-n-slate-8 transition-all duration-200 motion-safe:group-hover:animate-bounce"
        :class="{ 'bg-n-slate-8 animate-bounce': isResizing }"
      />
    </div>
    <slot />
  </div>
</template>

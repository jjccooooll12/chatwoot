import { ref, computed, onMounted, onBeforeUnmount } from 'vue';

// FRESHDESK-SKIN: phones open the nav drawer either from a page header's own
// menu button or, on pages without one, from the floating launcher. Shared
// module state, because the drawer lives in Dashboard while the buttons live
// in whichever page is showing.
const isOpen = ref(false);
const headerToggleCount = ref(0);

export function useMobileSidebar() {
  return {
    isOpen,
    hasHeaderToggle: computed(() => headerToggleCount.value > 0),
    toggle: () => {
      isOpen.value = !isOpen.value;
    },
    close: () => {
      isOpen.value = false;
    },
  };
}

// Called by a header menu button so the floating launcher steps aside while
// that header is on screen.
export function useRegisterHeaderToggle() {
  onMounted(() => {
    headerToggleCount.value += 1;
  });
  onBeforeUnmount(() => {
    headerToggleCount.value -= 1;
  });
}

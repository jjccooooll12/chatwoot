import { computed } from 'vue';
import { useWindowSize } from '@vueuse/core';
import wootConstants from 'dashboard/constants/globals';

// FRESHDESK-SKIN: the JS twin of Tailwind's `md:` breakpoint. Below it the
// dashboard uses its phone layout (drawer nav, bottom sheets instead of side
// columns). Use CSS (`md:hidden`) where it is enough; this is for behaviour.
export function useIsMobile() {
  const { width } = useWindowSize();
  return computed(() => width.value < wootConstants.SMALL_SCREEN_BREAKPOINT);
}

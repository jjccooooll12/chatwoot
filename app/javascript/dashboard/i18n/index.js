// FRESHDESK-SKIN: the agent UI ships in English only. Every locale used to be
// bundled into the dashboard's main script - ~13.8 MB raw, almost all of it
// translations nobody here uses - which phones on a weak connection could not
// finish downloading after a deploy, so the app never started. The other
// locale folders stay in the repo for upstream merges; they are just not
// bundled. Entrypoints fall back to English for any other configured locale.
import en from './locale/en';

export default { en };

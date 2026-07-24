# Freshdesk Skin Overrides

This fork is pinned to Chatwoot `v4.16.1` and carries Peach Labels support UI
customisations. Keep changes small, marked here, and revertable through normal
Git commits.

## Frontend

| Path                                                                                | Why                                                                                                                                                                                                                              | Upstream base               |
| ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| `theme/colors.js`                                                                   | Adds `fd.*` Tailwind colour tokens for the Freshdesk-style ticket card.                                                                                                                                                          | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components/widgets/conversation/ConversationCard.vue`     | Replaces the default condensed conversation row with a Freshdesk-style ticket card while preserving existing click, bulk select, context menu, priority, status, assignment, SLA, unread, message preview, and voice-call hooks. | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components/widgets/conversation/FreshdeskListToolbar.vue` | Adds the Freshdesk-style select-all, status, sort, layout, range, and filter toolbar above the ticket cards.                                                                                                                     | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components-next/filter/ConversationFilter.vue`            | Adds a side-panel presentation mode for the existing Chatwoot conversation filter builder. The filter payload and API path are unchanged.                                                                                        | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components/ConversationItem.vue` | Always renders the Freshdesk `ConversationCard` (full-width list included) and drops Chatwoot's expanded/table card; still wires inline assignment, priority, and status to the store. | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | Forces the full-width ticket list + full-screen ticket model (Freshdesk-style, no split pane); the message thread shows only after clicking a ticket, with the native back button. | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components/ChatList.vue`                                  | Widens the conversation list pane, mounts the Freshdesk toolbar, and presents filters as a right-side panel while keeping the existing filter actions.                                                                           | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components/ConversationList.vue` | Freshdesk light list background behind cards; expanded/table-card plumbing removed. | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components/ChatListHeader.vue` | Freshdesk-style list header: bolder title, always-on purple total-count badge, and a subtler status chip. | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/i18n/locale/en/chatlist.json`                             | Adds English strings for derived ticket-card labels. Crowdin owns other locales.                                                                                                                                                 | `chatwoot/chatwoot@v4.16.1` |

## Deployment

The deploy repo should point Compose at a pinned GHCR image tag, not at mutable
upstream `latest` tags. Rollback is changing the image tag back to the prior
known-good value and running the deploy script.

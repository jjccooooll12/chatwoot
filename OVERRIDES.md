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
| `app/javascript/dashboard/components/widgets/conversation/FreshdeskStatusPanel.vue` | Persistent right-side filter rail: Status (Open/Pending/Closed→resolved/Snoozed/All) + Assignee (Mine/Unassigned/All) + a More-filters entry, wired to the existing conversation status/assignee query. | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` | Renames "My Inbox" → "Tickets" and points it at the Freshdesk ticket view (`home` route); removes the entire "Conversations" nav group and the now-orphaned sort/unread-count helpers; forces the desktop sidebar into a 56px Freshdesk-style icon rail; mounts the bottom-left phone dialer above the profile menu. | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components-next/sidebar/SidebarDialer.vue`, `app/controllers/api/v1/accounts/calls_controller.rb`, `app/controllers/webhooks/twilio_voice_controller.rb` | Adds the bottom-left outbound call dialer, real `voice_calls` history, and community Twilio Voice outbound initiation through the custom API inbox instead of Chatwoot Enterprise call routes. | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components-next/sidebar/SidebarGroup.vue` | Restyles collapsed rail entries so active navigation uses the Freshdesk purple rounded-square treatment while preserving the existing route and popover behavior. | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components-next/filter/ConversationFilter.vue`            | Adds a side-panel presentation mode for the existing Chatwoot conversation filter builder. The filter payload and API path are unchanged.                                                                                        | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components/ConversationItem.vue` | Always renders the Freshdesk `ConversationCard` (full-width list included) and drops Chatwoot's expanded/table card; still wires inline assignment, priority, and status to the store. | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/routes/dashboard/conversation/ConversationView.vue` | Forces the full-width ticket list + full-screen ticket model (Freshdesk-style, no split pane); the message thread shows only after clicking a ticket, with the native back button. | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components/ChatList.vue`                                  | Widens the conversation list pane, mounts the Freshdesk toolbar, and presents filters as a right-side panel while keeping the existing filter actions.                                                                           | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components/ConversationList.vue` | Freshdesk light list background behind cards; expanded/table-card plumbing removed. | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components/ChatListHeader.vue` | Freshdesk-style list header/top bar: bolder title, always-on purple total-count badge, subtler status chip, `+ New`, search, notifications, help/apps affordances, and agent avatar. | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/i18n/locale/en/chatlist.json`                             | Adds English strings for derived ticket-card and top-bar labels. Crowdin owns other locales.                                                                                                                                     | `chatwoot/chatwoot@v4.16.1` |

## Deployment

The deploy repo should point Compose at a pinned GHCR image tag, not at mutable
upstream `latest` tags. Rollback is changing the image tag back to the prior
known-good value and running the deploy script.

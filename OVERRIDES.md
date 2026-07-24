# Freshdesk Skin Overrides

This fork is pinned to Chatwoot `v4.16.1` and carries Peach Labels support UI
customisations. Keep changes small, marked here, and revertable through normal
Git commits.

## Frontend

| Path                                                                            | Why                                                                                                                                                                                                                              | Upstream base               |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| `theme/colors.js`                                                               | Adds `fd.*` Tailwind colour tokens for the Freshdesk-style ticket card.                                                                                                                                                          | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components/widgets/conversation/ConversationCard.vue` | Replaces the default condensed conversation row with a Freshdesk-style ticket card while preserving existing click, bulk select, context menu, priority, status, assignment, SLA, unread, message preview, and voice-call hooks. | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components/ConversationItem.vue`                      | Wires inline card assignment, priority, and status controls back to the existing Chatwoot store actions.                                                                                                                         | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components/ChatList.vue`                              | Widens the conversation list pane so the Freshdesk-style card property column fits.                                                                                                                                              | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/components/ConversationList.vue`                      | Applies the Freshdesk light list background behind cards.                                                                                                                                                                        | `chatwoot/chatwoot@v4.16.1` |
| `app/javascript/dashboard/i18n/locale/en/chatlist.json`                         | Adds English strings for derived ticket-card labels. Crowdin owns other locales.                                                                                                                                                 | `chatwoot/chatwoot@v4.16.1` |

## Deployment

The deploy repo should point Compose at a pinned GHCR image tag, not at mutable
upstream `latest` tags. Rollback is changing the image tag back to the prior
known-good value and running the deploy script.

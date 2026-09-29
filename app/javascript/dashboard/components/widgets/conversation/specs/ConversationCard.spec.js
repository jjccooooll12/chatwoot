import { shallowMount } from '@vue/test-utils';
import ConversationCard from '../ConversationCard.vue';

// The card reads the inline agent picker's options straight off the store.
vi.mock('vuex', () => ({
  useStore: () => ({
    dispatch: vi.fn(),
    getters: { 'inboxAssignableAgents/getAssignableAgents': () => [] },
  }),
}));

const defaultChat = {
  id: 1,
  labels: [],
  messages: [],
  priority: null,
  unread_count: 0,
  timestamp: 1700000000,
  created_at: 1700000000,
};

const mountComponent = (chat, currentContact = {}) =>
  shallowMount(ConversationCard, {
    props: {
      chat: { ...defaultChat, ...chat },
      currentContact: {
        name: 'Jane Doe',
        thumbnail: '',
        availability_status: 'offline',
        ...currentContact,
      },
      inbox: { id: 1 },
    },
    global: {
      stubs: {
        'fluent-icon': true,
      },
    },
  });

const pillLabels = wrapper =>
  wrapper.findAll('span.rounded').map(pill => pill.text());

// A ticket somebody has already replied to, so the "New" pill is out of the way.
const repliedTo = { first_reply_created_at: 1700000000 };

describe('ConversationCard', () => {
  it('shows no pill for a ticket sitting in Open or Pending', () => {
    expect(
      pillLabels(mountComponent({ ...repliedTo, status: 'open' }))
    ).toEqual([]);
    expect(
      pillLabels(mountComponent({ ...repliedTo, status: 'pending' }))
    ).toEqual([]);
  });

  it('still flags a closed ticket', () => {
    expect(
      pillLabels(mountComponent({ ...repliedTo, status: 'resolved' }))
    ).toEqual(['Closed']);
  });

  it('keeps the pills that say something a status cannot', () => {
    expect(pillLabels(mountComponent({ status: 'open' }))).toEqual(['New']);
    expect(
      pillLabels(
        mountComponent({
          ...repliedTo,
          status: 'open',
          messages: [{ id: 1, message_type: 0, created_at: 1700000000 }],
        })
      )
    ).toEqual(['Customer responded']);
  });
});

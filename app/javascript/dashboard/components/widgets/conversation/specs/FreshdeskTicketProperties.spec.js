import { mount, flushPromises } from '@vue/test-utils';
import { reactive } from 'vue';
import FreshdeskTicketProperties from '../FreshdeskTicketProperties.vue';

const dispatch = vi.fn(() => Promise.resolve());
const getters = {
  'teams/getTeams': [{ id: 4, name: 'Support' }],
  'inboxAssignableAgents/getAssignableAgents': () => [
    { id: 7, name: 'Libero Cole', assignee_type: 'User' },
  ],
};

vi.mock('vuex', () => ({
  useStore: () => ({ dispatch, getters }),
}));

const buildChat = overrides =>
  reactive({
    id: 1,
    inbox_id: 2,
    status: 'open',
    priority: null,
    custom_attributes: {},
    meta: { team: null, assignee: null },
    ...overrides,
  });

const mountPanel = chat =>
  mount(FreshdeskTicketProperties, { props: { chat } });

const updateButton = wrapper =>
  wrapper.findAll('button').find(button => button.text() === 'Update');

// Opens the nth property dropdown and picks the option with that label.
const pick = async (wrapper, index, label) => {
  const select = wrapper.findAll('[aria-haspopup="listbox"]')[index];
  await select.trigger('click');
  const option = wrapper
    .findAll('li button')
    .find(button => button.text() === label);
  await option.trigger('click');
};

const STATUS = 3;
const GROUP = 4;

describe('FreshdeskTicketProperties', () => {
  beforeEach(() => dispatch.mockClear());

  it('keeps Update disabled and grey while nothing changed', () => {
    const wrapper = mountPanel(buildChat());
    const button = updateButton(wrapper);
    expect(button.attributes('disabled')).toBeDefined();
    expect(button.classes()).toContain('bg-fd-border');
  });

  it('stages a status change until Update is clicked', async () => {
    const wrapper = mountPanel(buildChat());
    dispatch.mockClear();
    await pick(wrapper, STATUS, 'Pending');

    expect(dispatch).not.toHaveBeenCalled();
    const button = updateButton(wrapper);
    expect(button.attributes('disabled')).toBeUndefined();
    expect(button.classes()).toContain('bg-fd-primary');

    await button.trigger('click');
    await flushPromises();
    expect(dispatch).toHaveBeenCalledWith('toggleStatus', {
      conversationId: 1,
      status: 'pending',
      snoozedUntil: null,
    });
    expect(dispatch).toHaveBeenCalledTimes(1);
  });

  it('goes grey again when the change is reverted', async () => {
    const wrapper = mountPanel(buildChat());
    await pick(wrapper, GROUP, 'Support');
    expect(updateButton(wrapper).attributes('disabled')).toBeUndefined();
    await pick(wrapper, GROUP, 'None');
    expect(updateButton(wrapper).attributes('disabled')).toBeDefined();
  });

  it('follows the saved value once the store confirms it', async () => {
    const chat = buildChat();
    const wrapper = mountPanel(chat);
    await pick(wrapper, STATUS, 'Pending');
    chat.status = 'pending';
    await flushPromises();
    expect(updateButton(wrapper).attributes('disabled')).toBeDefined();
  });
});

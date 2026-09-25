import { mount } from '@vue/test-utils';
import FreshdeskPropertySelect from '../FreshdeskPropertySelect.vue';

const options = [
  { value: 'open', label: 'Open' },
  { value: 'pending', label: 'Pending' },
  { value: 'resolved', label: 'Closed', dotClass: 'bg-n-teal-9' },
];

const mountSelect = modelValue =>
  mount(FreshdeskPropertySelect, { props: { modelValue, options } });

describe('FreshdeskPropertySelect', () => {
  it('shows the selected label and keeps the list closed', () => {
    const wrapper = mountSelect('pending');
    expect(wrapper.find('button').text()).toBe('Pending');
    expect(wrapper.find('ul').exists()).toBe(false);
  });

  it('renders every option as a pointer-cursor button when opened', async () => {
    const wrapper = mountSelect('open');
    await wrapper.find('button').trigger('click');
    const items = wrapper.findAll('li button');
    expect(items.map(item => item.text())).toEqual([
      'Open',
      'Pending',
      'Closed',
    ]);
    items.forEach(item => expect(item.classes()).toContain('cursor-pointer'));
  });

  it('emits the new value and closes', async () => {
    const wrapper = mountSelect('open');
    await wrapper.find('button').trigger('click');
    await wrapper.findAll('li button')[2].trigger('click');
    expect(wrapper.emitted('update:modelValue')).toEqual([['resolved']]);
    expect(wrapper.find('ul').exists()).toBe(false);
  });

  it('does not emit when the current value is picked again', async () => {
    const wrapper = mountSelect('open');
    await wrapper.find('button').trigger('click');
    await wrapper.findAll('li button')[0].trigger('click');
    expect(wrapper.emitted('update:modelValue')).toBeUndefined();
  });

  it('matches numeric and string values alike', () => {
    const wrapper = mount(FreshdeskPropertySelect, {
      props: {
        modelValue: 0,
        options: [
          { value: '0', label: 'None' },
          { value: '4', label: 'Support' },
        ],
      },
    });
    expect(wrapper.find('button').text()).toBe('None');
  });
});

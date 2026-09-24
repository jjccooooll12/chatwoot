require 'rails_helper'

RSpec.describe VoiceCountryRoute do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_api, account: account) }
  let(:inbox) { channel.inbox }
  let(:agent) { create(:user, account: account, role: :agent) }

  it 'is valid with a country name, E.164-style prefix, and agent' do
    route = described_class.new(account: account, inbox: inbox, user: agent, country_name: 'Italy', phone_prefix: '+39')
    expect(route).to be_valid
  end

  it 'normalizes a prefix typed without the leading + or with 00' do
    %w[39 0039].each do |typed|
      route = described_class.new(account: account, inbox: inbox, user: agent, country_name: 'Italy', phone_prefix: typed)

      expect(route).to be_valid
      expect(route.phone_prefix).to eq('+39')
    end
  end

  it 'rejects a prefix that is not a country calling code' do
    route = described_class.new(account: account, inbox: inbox, user: agent, country_name: 'Italy', phone_prefix: 'not-a-prefix')
    expect(route).not_to be_valid
  end

  it 'rejects a duplicate agent for the same inbox + prefix' do
    described_class.create!(account: account, inbox: inbox, user: agent, country_name: 'Italy', phone_prefix: '+39')
    duplicate = described_class.new(account: account, inbox: inbox, user: agent, country_name: 'Italy', phone_prefix: '+39')

    expect(duplicate).not_to be_valid
  end

  it 'allows the same prefix with different agents' do
    described_class.create!(account: account, inbox: inbox, user: agent, country_name: 'Italy', phone_prefix: '+39')
    other_agent = create(:user, account: account, role: :agent)
    second = described_class.new(account: account, inbox: inbox, user: other_agent, country_name: 'Italy', phone_prefix: '+39')

    expect(second).to be_valid
  end
end

require 'rails_helper'

RSpec.describe 'Voice Country Routes API', type: :request do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_api, account: account) }
  let(:inbox) { channel.inbox }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:super_admin) do
    create(:super_admin).tap { |user| create(:account_user, account: account, user: user, role: :administrator) }
  end
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /inboxes/:inbox_id/voice_country_routes' do
    it 'is forbidden for a regular agent' do
      get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/voice_country_routes", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:forbidden)
    end

    it 'lists routes for the super admin' do
      create(:voice_country_route, account: account, inbox: inbox, user: agent, country_name: 'Italy', phone_prefix: '+39')

      get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/voice_country_routes", headers: super_admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.first['country_name']).to eq('Italy')
    end
  end

  describe 'POST /inboxes/:inbox_id/voice_country_routes' do
    # Routing decides whose phone rings, so it is narrower than other settings.
    it 'is forbidden for an account administrator' do
      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/voice_country_routes",
           params: { voice_country_route: { country_name: 'Spain', phone_prefix: '+34', user_id: agent.id } },
           headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:forbidden)
    end

    it 'creates a route for the super admin' do
      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/voice_country_routes",
           params: { voice_country_route: { country_name: 'Spain', phone_prefix: '+34', user_id: agent.id } },
           headers: super_admin.create_new_auth_token

      expect(response).to have_http_status(:created)
      expect(VoiceCountryRoute.last.phone_prefix).to eq('+34')
    end

    it 'is forbidden for a regular agent' do
      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/voice_country_routes",
           params: { voice_country_route: { country_name: 'Spain', phone_prefix: '+34', user_id: agent.id } },
           headers: agent.create_new_auth_token

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns errors for an invalid prefix' do
      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/voice_country_routes",
           params: { voice_country_route: { country_name: 'Spain', phone_prefix: 'not-a-prefix', user_id: agent.id } },
           headers: super_admin.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /inboxes/:inbox_id/voice_country_routes/:id' do
    it 'removes the route for the super admin' do
      route = create(:voice_country_route, account: account, inbox: inbox, user: agent)

      delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/voice_country_routes/#{route.id}",
             headers: super_admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(VoiceCountryRoute.exists?(route.id)).to be false
    end

    it 'is forbidden for a regular agent' do
      route = create(:voice_country_route, account: account, inbox: inbox, user: agent)

      delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/voice_country_routes/#{route.id}",
             headers: agent.create_new_auth_token

      expect(response).to have_http_status(:forbidden)
      expect(VoiceCountryRoute.exists?(route.id)).to be true
    end
  end
end

# One-off provisioning for the single Voice inbox this account will ever
# have — not the generic multi-tenant Inboxes wizard, since there's exactly
# one Twilio Voice number for one account here.
#
# Usage:
#   ACCOUNT_ID=1 PHONE_NUMBER=+15551234567 \
#   TWILIO_ACCOUNT_SID=AC... TWILIO_TWIML_APP_SID=AP... TWILIO_API_KEY_SID=SK... \
#   AGENT_EMAILS=a@peach-labels.com,b@peach-labels.com,c@peach-labels.com \
#   bundle exec rake voice_inbox:create
namespace :voice_inbox do
  desc 'Create the Voice inbox (Channel::Api) and add agents as members'
  task create: :environment do
    account = Account.find(ENV.fetch('ACCOUNT_ID'))
    phone_number = ENV.fetch('PHONE_NUMBER')
    agent_emails = ENV.fetch('AGENT_EMAILS').split(',').map(&:strip)

    channel = Channel::Api.create!(
      account: account,
      additional_attributes: {
        phone_number: phone_number,
        twilio_account_sid: ENV.fetch('TWILIO_ACCOUNT_SID'),
        twilio_twiml_app_sid: ENV.fetch('TWILIO_TWIML_APP_SID'),
        twilio_api_key_sid: ENV.fetch('TWILIO_API_KEY_SID')
      }
    )

    inbox = Inbox.create!(account: account, channel: channel, name: 'Voice')

    users = account.users.where(email: agent_emails)
    missing = agent_emails - users.pluck(:email)
    puts "WARNING: no user found for: #{missing.join(', ')}" if missing.any?

    users.each { |user| InboxMember.find_or_create_by!(inbox: inbox, user: user) }

    puts "Created Voice inbox (id=#{inbox.id}) for #{phone_number}, members: #{users.pluck(:email).join(', ')}"
  end
end

FactoryBot.define do
  factory :voice_call do
    account
    inbox
    conversation
    contact
    sequence(:provider_call_id) { |n| "CA_test_#{n}" }
    direction { 'incoming' }
    status { 'ringing' }
    sequence(:conference_sid) { |n| "voice-test-#{n}" }
    from_number { '+15550001111' }
    to_number { '+15550002222' }
  end
end

FactoryBot.define do
  factory :voice_country_route do
    account
    inbox
    user
    country_name { 'Italy' }
    sequence(:phone_prefix) { |n| "+#{390 + n}" }
  end
end

# == Schema Information
#
# Table name: voice_country_routes
#
#  id            :bigint           not null, primary key
#  country_name  :string           not null
#  phone_prefix  :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  inbox_id      :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_voice_country_routes_on_inbox_prefix_user  (inbox_id,phone_prefix,user_id) UNIQUE
#

class VoiceCountryRoute < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :user

  validates :country_name, presence: true
  validates :phone_prefix, presence: true, format: { with: /\A\+\d{1,4}\z/, message: 'must be a leading + followed by 1-4 digits, e.g. +39' }
  validates :user_id, uniqueness: { scope: [:inbox_id, :phone_prefix] }

  def push_event_data
    {
      id: id,
      country_name: country_name,
      phone_prefix: phone_prefix,
      user_id: user_id,
      user_name: user.name
    }
  end
end

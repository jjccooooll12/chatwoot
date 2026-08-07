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
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (inbox_id => inboxes.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#

class VoiceCountryRoute < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :user

  before_validation :normalize_phone_prefix
  before_validation :adopt_existing_country_name

  validates :country_name, presence: true
  validates :phone_prefix, presence: true, format: { with: /\A\+\d{1,4}\z/, message: 'must be a country calling code, e.g. +39' }
  validate :agent_is_an_account_member
  validate :agent_not_already_routed_for_prefix

  def push_event_data
    {
      id: id,
      country_name: country_name,
      phone_prefix: phone_prefix,
      user_id: user_id,
      user_name: user.available_name
    }
  end

  private

  # Accept "39", "0039" or "+39" — the leading + is presentation, not
  # information, and rejecting it as a format error read as "adding a rule
  # does nothing" from the settings page.
  def normalize_phone_prefix
    digits = phone_prefix.to_s.gsub(/\D/, '')
    self.phone_prefix = "+#{digits}" if digits.present?
  end

  # A prefix is the real identity of a rule; the country name is only its
  # label. Without this, "USA +1" and "U.S.A. +1" render as two separate
  # groups for one set of agents, so the first rule for a prefix names it.
  def adopt_existing_country_name
    self.country_name = country_name.to_s.strip
    return if inbox_id.blank? || phone_prefix.blank?

    existing = self.class.where(inbox_id: inbox_id, phone_prefix: phone_prefix).where.not(id: id).pick(:country_name)
    self.country_name = existing if existing.present?
  end

  def agent_is_an_account_member
    return if user_id.blank? || account_id.blank?
    return if AccountUser.exists?(account_id: account_id, user_id: user_id)

    errors.add(:base, 'That agent is no longer a member of this account')
  end

  def agent_not_already_routed_for_prefix
    return if user_id.blank? || inbox_id.blank? || phone_prefix.blank?

    duplicates = self.class.where(inbox_id: inbox_id, phone_prefix: phone_prefix, user_id: user_id).where.not(id: id)
    return unless duplicates.exists?

    errors.add(:base, "#{user&.available_name} already receives #{phone_prefix} calls")
  end
end

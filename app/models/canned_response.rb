# == Schema Information
#
# Table name: canned_responses
#
#  id             :integer          not null, primary key
#  content        :text
#  short_code     :string
#  visibility     :integer          default("personal"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :integer          not null
#  created_by_id  :bigint
#  updated_by_id  :bigint
#

class CannedResponse < ApplicationRecord
  validates :content, presence: true
  validates :short_code, presence: true
  validates :account, presence: true
  validates :short_code, uniqueness: { scope: :account_id }

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  # Same personal/global convention as Macro — personal responses are only
  # visible to their creator, global ones to the whole account.
  enum visibility: { personal: 0, global: 1 }

  scope :order_by_search, lambda { |search|
    short_code_starts_with = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 1', "#{search}%"])
    short_code_like = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 0.5', "%#{search}%"])
    content_like = sanitize_sql_array(['WHEN content ILIKE ? THEN 0.2', "%#{search}%"])

    order_clause = "CASE #{short_code_starts_with} #{short_code_like} #{content_like} ELSE 0 END"

    order(Arel.sql(order_clause) => :desc)
  }

  def set_visibility(user, params)
    self.visibility = params[:visibility] if params[:visibility]
    self.visibility = :personal if user.agent?
  end

  def self.with_visibility(user, _params)
    records = Current.account.canned_responses.global
    records.or(personal.where(created_by_id: user.id, account_id: Current.account.id))
  end
end

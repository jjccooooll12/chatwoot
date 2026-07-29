class CannedResponseFolder < ApplicationRecord
  belongs_to :account
  has_many :canned_responses,
           foreign_key: :folder_id,
           dependent: :nullify,
           inverse_of: :folder

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id }
end

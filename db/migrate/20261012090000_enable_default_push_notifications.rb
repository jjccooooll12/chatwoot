# Push for everything a customer sends is now on by default (see
# NotificationSetting::DEFAULT_PUSH_FLAGS); switch it on for existing agents too.
# Each agent can still turn types off in Profile settings afterwards.
# Bits are FlagShihTzu positions (2**(type - 1)) of Notification::NOTIFICATION_TYPES:
# creation 1, assignment 2, assigned new message 4, mention 8, participating new
# message 16, unassigned new message 256.
class EnableDefaultPushNotifications < ActiveRecord::Migration[7.1]
  DEFAULT_PUSH_BITS = 1 | 2 | 4 | 8 | 16 | 256

  def up
    execute("UPDATE notification_settings SET push_flags = push_flags | #{DEFAULT_PUSH_BITS}")
  end

  def down; end
end

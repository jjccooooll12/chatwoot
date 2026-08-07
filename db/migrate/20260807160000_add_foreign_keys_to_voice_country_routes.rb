class AddForeignKeysToVoiceCountryRoutes < ActiveRecord::Migration[7.1]
  # voice_country_routes.user_id was a bare bigint with no referential
  # integrity, so deleting an agent left rules pointing at a user that no
  # longer existed. VoiceCountryRoute#push_event_data reads user.name, so a
  # single orphan row made the whole settings page 500 — the rules looked
  # like they had "disappeared" and newly added ones never showed up either,
  # because the list reload after a successful create failed the same way.
  def up
    execute(<<~SQL.squish)
      DELETE FROM voice_country_routes
      WHERE user_id NOT IN (SELECT id FROM users)
         OR inbox_id NOT IN (SELECT id FROM inboxes)
         OR account_id NOT IN (SELECT id FROM accounts)
    SQL

    # An agent removed from the account (User row kept, membership dropped)
    # can't answer its calls, so their rules are dead weight too. Agents::DestroyJob
    # keeps this true going forward; this clears what pre-dates it.
    execute(<<~SQL.squish)
      DELETE FROM voice_country_routes vcr
      WHERE NOT EXISTS (
        SELECT 1 FROM account_users au
        WHERE au.user_id = vcr.user_id AND au.account_id = vcr.account_id
      )
    SQL

    # The prefix is the rule's identity, the country name only its label, so
    # one prefix must carry one label — otherwise "USA +1" and "U.S.A. +1"
    # render as two separate groups for the same set of agents. The oldest
    # row for a prefix names it, matching VoiceCountryRoute's before_validation.
    execute(<<~SQL.squish)
      UPDATE voice_country_routes vcr
      SET country_name = canonical.country_name
      FROM (
        SELECT DISTINCT ON (inbox_id, phone_prefix) inbox_id, phone_prefix, country_name
        FROM voice_country_routes
        ORDER BY inbox_id, phone_prefix, id
      ) canonical
      WHERE vcr.inbox_id = canonical.inbox_id
        AND vcr.phone_prefix = canonical.phone_prefix
        AND vcr.country_name IS DISTINCT FROM canonical.country_name
    SQL

    add_foreign_key :voice_country_routes, :users, on_delete: :cascade
    add_foreign_key :voice_country_routes, :inboxes, on_delete: :cascade
    add_foreign_key :voice_country_routes, :accounts, on_delete: :cascade
  end

  def down
    remove_foreign_key :voice_country_routes, :users
    remove_foreign_key :voice_country_routes, :inboxes
    remove_foreign_key :voice_country_routes, :accounts
  end
end

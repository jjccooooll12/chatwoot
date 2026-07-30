class CreateVoiceCountryRoutes < ActiveRecord::Migration[7.1]
  def change
    create_table :voice_country_routes do |t|
      t.bigint :account_id, null: false
      t.bigint :inbox_id, null: false
      t.bigint :user_id, null: false
      t.string :country_name, null: false
      t.string :phone_prefix, null: false

      t.timestamps
    end

    add_index :voice_country_routes, [:inbox_id, :phone_prefix, :user_id], unique: true, name: 'index_voice_country_routes_on_inbox_prefix_user'
    add_index :voice_country_routes, :account_id
  end
end

class CreateCannedResponseFolders < ActiveRecord::Migration[7.1]
  def change
    create_table :canned_response_folders do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :canned_response_folders, [:account_id, :name], unique: true

    add_column :canned_responses, :folder_id, :bigint
    add_index :canned_responses, :folder_id
  end
end

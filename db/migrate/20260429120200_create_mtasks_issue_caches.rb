class CreateMtasksIssueCaches < ActiveRecord::Migration[8.1]
  def change
    create_table :mtasks_issue_caches, id: false do |t|
      t.bigint :mtasks_issue_id, primary_key: true
      t.string :identifier, null: false
      t.string :title
      t.string :status_name
      t.bigint :lane_id
      t.string :priority
      t.string :assignee_email
      t.jsonb :labels, default: [], null: false
      t.string :url
      t.jsonb :payload, default: {}, null: false
      t.datetime :last_synced_at
      t.datetime :deleted_at
    end

    add_index :mtasks_issue_caches, :identifier
    add_index :mtasks_issue_caches, :deleted_at
  end
end

class CreateMtasksProjectCaches < ActiveRecord::Migration[8.1]
  def change
    create_table :mtasks_project_caches, id: false do |t|
      t.bigint :mtasks_project_id, primary_key: true
      t.string :name, null: false
      t.text :description
      t.string :status
      t.string :url
      t.jsonb :payload, default: {}, null: false
      t.datetime :last_synced_at
    end
  end
end

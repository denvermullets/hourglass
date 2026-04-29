class CreateMtasksLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :mtasks_links do |t|
      t.string :link_type, null: false
      t.references :server_integration, null: false, foreign_key: true
      t.references :channel, foreign_key: true
      t.references :thread, foreign_key: { to_table: :messages }
      t.bigint :mtasks_team_id, null: false
      t.bigint :mtasks_project_id
      t.bigint :mtasks_issue_id
      t.string :mtasks_issue_identifier
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :mtasks_links, :channel_id,
              unique: true,
              where: "link_type = 'project_channel'",
              name: 'index_mtasks_links_unique_channel_per_project_link'
    add_index :mtasks_links, :thread_id,
              unique: true,
              where: "link_type = 'issue_thread'",
              name: 'index_mtasks_links_unique_thread_per_issue_link'
    add_index :mtasks_links, :mtasks_project_id,
              unique: true,
              where: "link_type = 'project_channel'",
              name: 'index_mtasks_links_unique_project_per_channel_link'
    add_index :mtasks_links, :mtasks_issue_id,
              unique: true,
              where: "link_type = 'issue_thread'",
              name: 'index_mtasks_links_unique_issue_per_thread_link'
  end
end

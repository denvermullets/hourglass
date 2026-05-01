# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_30_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.datetime "revoked_at"
    t.jsonb "scopes", default: ["read", "write"], null: false
    t.bigint "server_id"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["server_id"], name: "index_api_tokens_on_server_id"
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id", "revoked_at"], name: "index_api_tokens_on_user_id_and_revoked_at"
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.bigint "server_id", null: false
    t.datetime "updated_at", null: false
    t.index ["server_id", "position"], name: "index_categories_on_server_id_and_position"
    t.index ["server_id"], name: "index_categories_on_server_id"
  end

  create_table "channel_memberships", force: :cascade do |t|
    t.bigint "channel_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_read_at"
    t.boolean "muted", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["channel_id"], name: "index_channel_memberships_on_channel_id"
    t.index ["user_id", "channel_id"], name: "index_channel_memberships_on_user_id_and_channel_id", unique: true
    t.index ["user_id"], name: "index_channel_memberships_on_user_id"
  end

  create_table "channels", force: :cascade do |t|
    t.datetime "archived_at"
    t.bigint "category_id"
    t.integer "channel_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "is_private", default: false, null: false
    t.datetime "last_message_at"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.bigint "server_id", null: false
    t.string "topic"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_channels_on_category_id"
    t.index ["server_id", "category_id", "position"], name: "index_channels_on_server_id_and_category_id_and_position"
    t.index ["server_id", "name"], name: "index_channels_on_server_id_and_name", unique: true
    t.index ["server_id"], name: "index_channels_on_server_id"
  end

  create_table "conversation_memberships", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_read_at"
    t.boolean "muted", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["conversation_id"], name: "index_conversation_memberships_on_conversation_id"
    t.index ["user_id", "conversation_id"], name: "index_conversation_memberships_on_user_id_and_conversation_id", unique: true
    t.index ["user_id"], name: "index_conversation_memberships_on_user_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_group", default: false, null: false
    t.datetime "last_message_at"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "joined_at", null: false
    t.string "nickname"
    t.integer "role", default: 3, null: false
    t.bigint "server_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["server_id"], name: "index_memberships_on_server_id"
    t.index ["user_id", "server_id"], name: "index_memberships_on_user_id_and_server_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.text "body", null: false
    t.bigint "channel_id"
    t.bigint "conversation_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.datetime "edited_at"
    t.integer "message_type", default: 0, null: false
    t.bigint "parent_message_id"
    t.datetime "pinned_at"
    t.bigint "pinned_by_id"
    t.integer "replies_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["channel_id", "created_at"], name: "index_messages_on_channel_id_and_created_at"
    t.index ["channel_id"], name: "index_messages_on_channel_id"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["parent_message_id"], name: "index_messages_on_parent_message_id"
    t.index ["pinned_at"], name: "index_messages_on_pinned_at_partial", where: "(pinned_at IS NOT NULL)"
    t.index ["pinned_by_id"], name: "index_messages_on_pinned_by_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "mtasks_issue_caches", primary_key: "mtasks_issue_id", force: :cascade do |t|
    t.string "assignee_email"
    t.datetime "deleted_at"
    t.string "identifier", null: false
    t.jsonb "labels", default: [], null: false
    t.bigint "lane_id"
    t.datetime "last_synced_at"
    t.jsonb "payload", default: {}, null: false
    t.string "priority"
    t.string "status_name"
    t.string "title"
    t.string "url"
    t.index ["deleted_at"], name: "index_mtasks_issue_caches_on_deleted_at"
    t.index ["identifier"], name: "index_mtasks_issue_caches_on_identifier"
  end

  create_table "mtasks_links", force: :cascade do |t|
    t.bigint "channel_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.string "link_type", null: false
    t.bigint "mtasks_issue_id"
    t.string "mtasks_issue_identifier"
    t.bigint "mtasks_project_id"
    t.bigint "mtasks_team_id", null: false
    t.bigint "server_integration_id", null: false
    t.bigint "thread_id"
    t.datetime "updated_at", null: false
    t.index ["channel_id"], name: "index_mtasks_links_on_channel_id"
    t.index ["channel_id"], name: "index_mtasks_links_unique_channel_per_project_link", unique: true, where: "((link_type)::text = 'project_channel'::text)"
    t.index ["created_by_user_id"], name: "index_mtasks_links_on_created_by_user_id"
    t.index ["mtasks_issue_id"], name: "index_mtasks_links_unique_issue_per_thread_link", unique: true, where: "((link_type)::text = 'issue_thread'::text)"
    t.index ["mtasks_project_id"], name: "index_mtasks_links_unique_project_per_channel_link", unique: true, where: "((link_type)::text = 'project_channel'::text)"
    t.index ["server_integration_id"], name: "index_mtasks_links_on_server_integration_id"
    t.index ["thread_id"], name: "index_mtasks_links_on_thread_id"
    t.index ["thread_id"], name: "index_mtasks_links_unique_thread_per_issue_link", unique: true, where: "((link_type)::text = 'issue_thread'::text)"
  end

  create_table "mtasks_project_caches", primary_key: "mtasks_project_id", force: :cascade do |t|
    t.text "description"
    t.datetime "last_synced_at"
    t.string "name", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "status"
    t.string "url"
  end

  create_table "mtasks_user_maps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.bigint "hourglass_user_id", null: false
    t.datetime "last_synced_at"
    t.bigint "mtasks_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_mtasks_user_maps_on_email", unique: true
    t.index ["hourglass_user_id"], name: "index_mtasks_user_maps_on_hourglass_user_id"
    t.index ["hourglass_user_id"], name: "index_mtasks_user_maps_on_hourglass_user_id_unique", unique: true
    t.index ["mtasks_user_id"], name: "index_mtasks_user_maps_on_mtasks_user_id", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "actor_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.bigint "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.integer "notification_type", default: 0, null: false
    t.datetime "read_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "notification_type", "notifiable_type", "notifiable_id"], name: "idx_notifications_dedup"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "server_integrations", force: :cascade do |t|
    t.string "api_token"
    t.string "base_url", default: "https://justanotherissuetracker.com", null: false
    t.datetime "created_at", null: false
    t.jsonb "discovered_teams", default: [], null: false
    t.boolean "enabled", default: false, null: false
    t.string "kind", null: false
    t.datetime "last_verified_at"
    t.bigint "server_id", null: false
    t.datetime "updated_at", null: false
    t.string "webhook_secret"
    t.index ["server_id", "kind"], name: "index_server_integrations_on_server_id_and_kind", unique: true
    t.index ["server_id"], name: "index_server_integrations_on_server_id"
  end

  create_table "servers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "invite_code", null: false
    t.string "name", null: false
    t.bigint "owner_id", null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["invite_code"], name: "index_servers_on_invite_code", unique: true
    t.index ["owner_id"], name: "index_servers_on_owner_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "bio"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email_address", null: false
    t.jsonb "favorite_artists", default: []
    t.integer "onboarding_step", default: 0, null: false
    t.string "password_digest", null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "webhook_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "delivery_id", null: false
    t.string "event_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.datetime "received_at", null: false
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_webhook_deliveries_on_event_type"
    t.index ["processed_at"], name: "index_webhook_deliveries_on_processed_at"
    t.index ["source", "delivery_id"], name: "index_webhook_deliveries_on_source_and_delivery_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_tokens", "servers"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "categories", "servers"
  add_foreign_key "channel_memberships", "channels"
  add_foreign_key "channel_memberships", "users"
  add_foreign_key "channels", "categories"
  add_foreign_key "channels", "servers"
  add_foreign_key "conversation_memberships", "conversations"
  add_foreign_key "conversation_memberships", "users"
  add_foreign_key "memberships", "servers"
  add_foreign_key "memberships", "users"
  add_foreign_key "messages", "channels"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "messages", column: "parent_message_id"
  add_foreign_key "messages", "users"
  add_foreign_key "messages", "users", column: "pinned_by_id"
  add_foreign_key "mtasks_links", "channels"
  add_foreign_key "mtasks_links", "messages", column: "thread_id"
  add_foreign_key "mtasks_links", "server_integrations"
  add_foreign_key "mtasks_links", "users", column: "created_by_user_id"
  add_foreign_key "mtasks_user_maps", "users", column: "hourglass_user_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "server_integrations", "servers"
  add_foreign_key "servers", "users", column: "owner_id"
  add_foreign_key "sessions", "users"
end

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

ActiveRecord::Schema[8.1].define(version: 2026_03_31_200002) do
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

  create_table "categories", force: :cascade do |t|
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
    t.bigint "category_id"
    t.integer "channel_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "is_private", default: false, null: false
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
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "categories", "servers"
  add_foreign_key "channel_memberships", "channels"
  add_foreign_key "channel_memberships", "users"
  add_foreign_key "channels", "categories"
  add_foreign_key "channels", "servers"
  add_foreign_key "memberships", "servers"
  add_foreign_key "memberships", "users"
  add_foreign_key "servers", "users", column: "owner_id"
  add_foreign_key "sessions", "users"
end

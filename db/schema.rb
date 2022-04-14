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

ActiveRecord::Schema[7.0].define(version: 2022_04_14_145412) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "teams", force: :cascade do |t|
    t.string "slack_id"
    t.string "access_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "scopes"
    t.index ["slack_id"], name: "index_teams_on_slack_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "slack_id"
    t.bigint "team_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "location"
    t.index ["slack_id"], name: "index_users_on_slack_id"
    t.index ["team_id"], name: "index_users_on_team_id"
  end

  add_foreign_key "users", "teams"
end

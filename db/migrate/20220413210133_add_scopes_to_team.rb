class AddScopesToTeam < ActiveRecord::Migration[7.0]
  def change
    add_column :teams, :scopes, :string
  end
end

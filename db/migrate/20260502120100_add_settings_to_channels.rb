class AddSettingsToChannels < ActiveRecord::Migration[8.1]
  def change
    add_column :channels, :settings, :jsonb, default: {}, null: false
  end
end

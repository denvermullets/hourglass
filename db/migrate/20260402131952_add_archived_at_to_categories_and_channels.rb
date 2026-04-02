class AddArchivedAtToCategoriesAndChannels < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :archived_at, :datetime
    add_column :channels, :archived_at, :datetime
  end
end

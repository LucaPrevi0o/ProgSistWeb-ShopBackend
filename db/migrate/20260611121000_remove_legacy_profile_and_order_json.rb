class RemoveLegacyProfileAndOrderJson < ActiveRecord::Migration[8.1]
  def up
    remove_column :user_infos, :data if column_exists?(:user_infos, :data)
    remove_column :orders, :items if column_exists?(:orders, :items)
  end

  def down
    add_column :user_infos, :data, :json unless column_exists?(:user_infos, :data)
    add_column :orders, :items, :json, null: false, default: [] unless column_exists?(:orders, :items)
  end
end

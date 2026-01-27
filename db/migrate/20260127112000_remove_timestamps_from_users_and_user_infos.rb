class RemoveTimestampsFromUsersAndUserInfos < ActiveRecord::Migration[8.1]
  def up
    if column_exists?(:users, :created_at)
      remove_column :users, :created_at
    end
    if column_exists?(:users, :updated_at)
      remove_column :users, :updated_at
    end

    if column_exists?(:user_infos, :created_at)
      remove_column :user_infos, :created_at
    end
    if column_exists?(:user_infos, :updated_at)
      remove_column :user_infos, :updated_at
    end
  end

  def down
    unless column_exists?(:users, :created_at)
      add_column :users, :created_at, :datetime
    end
    unless column_exists?(:users, :updated_at)
      add_column :users, :updated_at, :datetime
    end

    unless column_exists?(:user_infos, :created_at)
      add_column :user_infos, :created_at, :datetime
    end
    unless column_exists?(:user_infos, :updated_at)
      add_column :user_infos, :updated_at, :datetime
    end
  end
end

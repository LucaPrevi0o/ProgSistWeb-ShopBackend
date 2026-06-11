class AddTimestampsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_timestamps :users, null: true
  end
end

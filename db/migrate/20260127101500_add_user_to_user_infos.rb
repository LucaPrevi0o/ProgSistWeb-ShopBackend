class AddUserToUserInfos < ActiveRecord::Migration[8.1]
  def change
    add_reference :user_infos, :user, null: false, foreign_key: true, index: true
  end
end

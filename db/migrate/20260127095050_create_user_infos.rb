class CreateUserInfos < ActiveRecord::Migration[8.1]
  def change
    create_table :user_infos do |t|
      t.string :first_name
      t.string :last_name
      t.string :phone

      t.timestamps
    end
  end
end

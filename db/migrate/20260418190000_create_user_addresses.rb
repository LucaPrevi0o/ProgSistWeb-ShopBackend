class CreateUserAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :user_addresses do |t|
      t.string :street
      t.string :city
      t.string :postal_code
      t.string :country

      t.references :user_info, null: false, foreign_key: true, index: true

      t.timestamps
    end
  end
end

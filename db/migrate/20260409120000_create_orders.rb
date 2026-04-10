class CreateOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :orders do |t|
      t.references :user, foreign_key: true, null: true
      t.string :status, null: false, default: 'pending'
      t.decimal :total, precision: 10, scale: 2, null: false, default: 0.0

      # customer information
      t.string :name
      t.string :surname
      t.string :address
      t.string :city
      t.string :postal_code
      t.string :country
      t.string :phone

      t.timestamps
    end
  end
end

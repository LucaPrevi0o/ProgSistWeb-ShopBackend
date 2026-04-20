class CreatePaymentMethods < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_methods do |t|
      t.references :user_info, null: false, foreign_key: true
      t.string :type, null: false
      t.json :details, default: {}

      t.timestamps
    end
  end
end

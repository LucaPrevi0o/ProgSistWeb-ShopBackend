class AddJsonColumnsToOrders < ActiveRecord::Migration[7.0]
  def change
    # Use generic JSON columns so migrations work with SQLite and Postgres
    add_column :orders, :personal_data, :json, null: false, default: {}
    add_column :orders, :items, :json, null: false, default: []
    add_column :orders, :payment_method, :json, null: false, default: {}
  end
end

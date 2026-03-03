class MigrateCartsToCartItems < ActiveRecord::Migration[8.1]
  def up
    # Create new carts table (one cart per user)
    create_table :carts_new do |t|
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    add_index :carts_new, :user_id, unique: true unless index_exists?(:carts_new, :user_id)

    # Create cart_items table
    create_table :cart_items do |t|
      t.references :cart, null: false, foreign_key: { to_table: :carts_new }
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.timestamps
    end

    add_index :cart_items, [:cart_id, :product_id], unique: true unless index_exists?(:cart_items, [:cart_id, :product_id])

    # Migrate existing data from old carts table
    if table_exists?(:carts)
      say_with_time "Migrating cart rows to carts_new + cart_items" do
        # For each old cart row, create/find a carts_new for the user and add a cart_item
        execute("SELECT id, user_id, product_id, quantity, created_at, updated_at FROM carts").to_a.each do |row|
          # row is an array-like; use raw SQL insertions to avoid model dependency
          user_id = row[1]
          product_id = row[2]
          quantity = row[3] || 1
          created_at = row[4] || Time.current
          updated_at = row[5] || Time.current

          # Find or create cart for user
          cart = select_all(["SELECT id FROM carts_new WHERE user_id = ? LIMIT 1", user_id]).first
          unless cart
            execute(["INSERT INTO carts_new (user_id, created_at, updated_at) VALUES (?, ?, ?)", user_id, created_at, updated_at])
            cart = select_all(["SELECT id FROM carts_new WHERE user_id = ? LIMIT 1", user_id]).first
          end

          cart_id = cart['id']

          # Insert cart_item
          execute(["INSERT INTO cart_items (cart_id, product_id, quantity, created_at, updated_at) VALUES (?, ?, ?, ?, ?)", cart_id, product_id, quantity, created_at, updated_at])
        end
      end
    end

    # Swap tables: drop old carts, rename carts_new to carts
    if table_exists?(:carts)
      drop_table :carts
    end

    rename_table :carts_new, :carts
  end

  def down
    # Recreate old carts table
    create_table :old_carts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.timestamps
    end

    add_index :old_carts, [:user_id, :product_id], unique: true

    # Migrate data back: for each cart (one per user), insert back cart rows from cart_items
    if table_exists?(:carts)
      say_with_time "Migrating cart_items back to old carts" do
        execute("SELECT id FROM carts").to_a.each do |crow|
          cart_id = crow[0]
          execute(["SELECT product_id, quantity, created_at, updated_at FROM cart_items WHERE cart_id = ?", cart_id]).to_a.each do |item|
            product_id = item[0]
            quantity = item[1] || 1
            created_at = item[2] || Time.current
            updated_at = item[3] || Time.current
            # find user_id for cart
            user = select_all(["SELECT user_id FROM carts WHERE id = ? LIMIT 1", cart_id]).first
            user_id = user['user_id']
            execute(["INSERT INTO old_carts (user_id, product_id, quantity, created_at, updated_at) VALUES (?, ?, ?, ?, ?)", user_id, product_id, quantity, created_at, updated_at])
          end
        end
      end
    end

    # drop cart_items and carts then rename old_carts
    drop_table :cart_items if table_exists?(:cart_items)
    drop_table :carts if table_exists?(:carts)
    rename_table :old_carts, :carts
  end
end

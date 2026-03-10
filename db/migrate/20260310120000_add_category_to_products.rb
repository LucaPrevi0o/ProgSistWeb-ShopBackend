class AddCategoryToProducts < ActiveRecord::Migration[8.1]
  def up
    add_column :products, :category, :string, null: false, default: 'UNCATEGORIZED'
    add_index :products, :category

    say_with_time "Assigning categories to existing products" do
      # ensure the model knows about the new column
      Product.reset_column_information
      Product.find_each do |p|
        text = "#{p.name} #{p.description}".to_s.downcase

        cat = case
        when text.match?(/\b(phone|tablet|laptop|camera|tv|headphone|earbud|charger|usb|electro)\b/)
          'ELECTRONICS'
        when text.match?(/\b(bag|belt|watch|sunglass|accessory|case|strap|jewelry|earring|necklace)\b/)
          'ACCESSORIES'
        when text.match?(/\b(shirt|trouser|jeans|dress|skirt|jacket|coat|hoodie|t-shirt|pants|sneaker|shoe|clothes)\b/)
          'CLOTHES'
        when text.match?(/\b(book|novel|magazine)\b/)
          'BOOKS'
        when text.match?(/\b(toy|game|lego|puzzle)\b/)
          'TOYS'
        when text.match?(/\b(sofa|table|chair|lamp|home|kitchen)\b/)
          'HOME'
        else
          'UNCATEGORIZED'
        end

        # use update_column to avoid callbacks/validations during migration
        p.update_column(:category, cat)
      end
    end
  end

  def down
    remove_index :products, :category if index_exists?(:products, :category)
    remove_column :products, :category
  end
end

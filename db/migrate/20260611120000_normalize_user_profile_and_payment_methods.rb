class NormalizeUserProfileAndPaymentMethods < ActiveRecord::Migration[8.1]
  def up
    create_table :personal_data do |t|
      t.references :user_info, null: false, foreign_key: true
      t.string :first_name
      t.string :last_name
      t.string :phone
      t.timestamps
    end

    create_table :addresses do |t|
      t.references :personal_data, null: false, foreign_key: true
      t.string :street
      t.string :city
      t.string :postal_code
      t.string :country
      t.timestamps
    end

    rename_column :payment_methods, :type, :method_type if column_exists?(:payment_methods, :type)

    say_with_time "Migrating user_infos.data into personal_data and addresses" do
      UserInfo.reset_column_information
      UserInfo.find_each do |user_info|
        data = normalize_json(user_info.data)
        next if data.blank?

        personal_data = execute_insert_personal_data(user_info.id, data)
        address = normalize_json(data["address"])
        execute_insert_address(personal_data, address) if address.present?
      end
    end
  end

  def down
    rename_column :payment_methods, :method_type, :type if column_exists?(:payment_methods, :method_type)
    drop_table :addresses if table_exists?(:addresses)
    drop_table :personal_data if table_exists?(:personal_data)
  end

  private

  def normalize_json(value)
    case value
    when String
      JSON.parse(value)
    when Hash
      value
    else
      {}
    end.with_indifferent_access
  rescue JSON::ParserError
    {}
  end

  def execute_insert_personal_data(user_info_id, data)
    now = quote(Time.current)
    execute <<~SQL.squish
      INSERT INTO personal_data (user_info_id, first_name, last_name, phone, created_at, updated_at)
      VALUES (
        #{quote(user_info_id)},
        #{quote(data["first_name"] || data["firstName"])},
        #{quote(data["last_name"] || data["lastName"])},
        #{quote(data["phone"])},
        #{now},
        #{now}
      )
    SQL

    select_value("SELECT id FROM personal_data WHERE user_info_id = #{quote(user_info_id)} ORDER BY id DESC LIMIT 1")
  end

  def execute_insert_address(personal_data_id, address)
    now = quote(Time.current)
    execute <<~SQL.squish
      INSERT INTO addresses (personal_data_id, street, city, postal_code, country, created_at, updated_at)
      VALUES (
        #{quote(personal_data_id)},
        #{quote(address["street"])},
        #{quote(address["city"])},
        #{quote(address["postal_code"] || address["postalCode"])},
        #{quote(address["country"])},
        #{now},
        #{now}
      )
    SQL
  end
end

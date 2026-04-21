class MigrateUserInfosToData < ActiveRecord::Migration[8.1]
  class MigrationUserInfo < ActiveRecord::Base
    self.table_name = 'user_infos'
    has_one :user_address, class_name: 'MigrationUserAddress', foreign_key: 'user_info_id'
  end

  class MigrationUserAddress < ActiveRecord::Base
    self.table_name = 'user_addresses'
  end

  def up
    unless column_exists?(:user_infos, :data)
      add_column :user_infos, :data, :json
    end

    MigrationUserInfo.reset_column_information
    MigrationUserAddress.reset_column_information

    MigrationUserInfo.find_each do |ui|
      data = (ui.data || {}).dup rescue {}
      data = {} unless data.is_a?(Hash)

      data['first_name'] = ui['first_name'] if ui.has_attribute?('first_name') && ui['first_name'].present?
      data['last_name'] = ui['last_name'] if ui.has_attribute?('last_name') && ui['last_name'].present?
      data['phone'] = ui['phone'] if ui.has_attribute?('phone') && ui['phone'].present?

      if ui.respond_to?(:user_address) && ui.user_address
        a = ui.user_address
        data['address'] = {
          'street' => a['street'],
          'city' => a['city'],
          'postal_code' => a['postal_code'],
          'country' => a['country']
        }.compact
      end

      ui.update_column(:data, data)
    end

    if table_exists?(:user_addresses)
      drop_table :user_addresses
    end

    if column_exists?(:user_infos, :first_name)
      remove_column :user_infos, :first_name
    end
    if column_exists?(:user_infos, :last_name)
      remove_column :user_infos, :last_name
    end
    if column_exists?(:user_infos, :phone)
      remove_column :user_infos, :phone
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Can't safely revert user info data migration"
  end
end

module Users
  class UpsertUserInfo < ApplicationService
    def initialize(user:, params:)
      @user = user
      @params = params.with_indifferent_access
    end

    def call
      ActiveRecord::Base.transaction do
        user_info = user.user_info || user.create_user_info!
        upsert_personal_data(user_info) if params.key?(:data)
        replace_payment_methods(user_info) if params.key?(:payment_methods)
        user_info
      end
    end

    private

    attr_reader :user, :params

    def upsert_personal_data(user_info)
      data = (params[:data] || {}).with_indifferent_access
      personal_data = user_info.personal_data || user_info.build_personal_data
      personal_data.assign_attributes(
        first_name: data[:first_name],
        last_name: data[:last_name],
        phone: data[:phone]
      )
      personal_data.save!

      address_attrs = data[:address]
      return unless address_attrs.present?

      address_attrs = address_attrs.with_indifferent_access
      address = personal_data.address || personal_data.build_address
      address.assign_attributes(
        street: address_attrs[:street],
        city: address_attrs[:city],
        postal_code: address_attrs[:postal_code],
        country: address_attrs[:country]
      )
      address.save!
    end

    def replace_payment_methods(user_info)
      user_info.payment_methods.destroy_all

      Array(params[:payment_methods]).each do |payment_method|
        payment_method = payment_method.with_indifferent_access
        next if payment_method[:method_type].blank?

        user_info.payment_methods.create!(
          method_type: payment_method[:method_type],
          details: payment_method[:details] || {}
        )
      end
    end
  end
end

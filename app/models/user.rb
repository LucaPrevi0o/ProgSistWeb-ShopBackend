class User < ApplicationRecord
  ROLES = %w[USER ADMIN].freeze

  has_secure_password

  has_one :user_info, dependent: :destroy
  has_one :cart, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :payment_methods, through: :user_info

  validates :role, inclusion: { in: ROLES }
  after_initialize :set_default_role, if: :new_record?

  def admin?
    role == 'ADMIN'
  end

  def user?
    role == 'USER'
  end

  private

  def set_default_role
    self.role ||= 'USER'
  end
end

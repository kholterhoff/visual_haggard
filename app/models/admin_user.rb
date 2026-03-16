class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  # Define searchable attributes for Ransack (used by ActiveAdmin)
  # Excludes sensitive fields like encrypted_password and reset_password_token
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "email", "id", "remember_created_at", "updated_at"]
  end
end

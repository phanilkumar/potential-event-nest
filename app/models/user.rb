class User < ApplicationRecord
  has_secure_password

  has_many :events
  has_many :orders

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :role, inclusion: { in: %w[organizer attendee admin] }

  def organizer?
    role == "organizer"
  end

  def attendee?
    role == "attendee"
  end

  def admin?
    role == "admin"
  end

  def generate_jwt
    JWT.encode(
      { user_id: id, exp: 24.hours.from_now.to_i },
      Rails.application.secret_key_base
    )
  end
end

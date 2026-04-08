class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :ticket_tier

  validates :quantity, presence: true
  validates :unit_price, presence: true

  def subtotal
    quantity * unit_price
  end
end

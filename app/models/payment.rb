class Payment < ApplicationRecord
  belongs_to :order

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[pending processing completed failed refunded] }

  def process!
    update!(status: "processing")
    if rand > 0.1
      update!(status: "completed", provider_reference: "ch_#{SecureRandom.hex(12)}")
      order.confirm!
    else
      update!(status: "failed", failure_reason: "Card declined")
    end
  end

  def refund!
    update!(status: "refunded")
    order.update!(status: "refunded")
  end
end

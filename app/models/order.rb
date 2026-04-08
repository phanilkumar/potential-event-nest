class Order < ApplicationRecord
  belongs_to :user
  belongs_to :event
  has_many :order_items, dependent: :destroy
  has_one :payment, dependent: :destroy

  before_create :generate_confirmation_number
  before_create :calculate_total
  after_create :reserve_ticket_inventory
  after_create :create_pending_payment
  after_create :send_confirmation_email
  after_create :track_analytics
  after_update :handle_status_change
  after_update :sync_with_crm

  validates :status, inclusion: { in: %w[pending confirmed cancelled refunded] }

  scope :confirmed, -> { where(status: "confirmed") }
  scope :recent, -> { order(created_at: :desc) }

  def confirm!
    update!(status: "confirmed")
  end

  def cancel!
    update!(status: "cancelled")
  end

  private

  def generate_confirmation_number
    self.confirmation_number = "EVN-#{SecureRandom.hex(4).upcase}"
  end

  def calculate_total
    self.total_amount = order_items.sum { |item| item.quantity * item.unit_price }
  end

  def reserve_ticket_inventory
    order_items.each do |item|
      item.ticket_tier.reserve_tickets!(item.quantity)
    end
  end

  def create_pending_payment
    Payment.create!(
      order: self,
      amount: total_amount,
      status: "pending"
    )
  end

  def send_confirmation_email
    UserMailer.order_confirmation(user, self).deliver_now
  end

  def track_analytics
    Rails.logger.info("Tracking order #{id} for analytics")
  end

  def handle_status_change
    if status_previously_changed?
      case status
      when "cancelled"
        UserMailer.order_cancelled(user, self).deliver_now
      when "confirmed"
        UserMailer.order_confirmed(user, self).deliver_now
      end
    end
  end

  def sync_with_crm
    CrmSyncJob.perform_later(self.id) if saved_changes.any?
  end
end

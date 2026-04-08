class Event < ApplicationRecord
  belongs_to :user
  has_many :ticket_tiers, dependent: :destroy
  has_many :orders

  validates :title, presence: true

  scope :published, -> { where(status: "published") }
  scope :upcoming, -> { where("starts_at > ?", Time.current) }

  after_update :notify_attendees_if_cancelled
  after_update :update_search_index
  after_create :send_organizer_confirmation
  before_save :geocode_venue

  def total_tickets
    ticket_tiers.sum(:quantity)
  end

  def total_sold
    ticket_tiers.sum(:sold_count)
  end

  def sold_out?
    total_sold >= total_tickets
  end

  def geocode_venue
    if venue.present?
      Rails.logger.info("Geocoding venue: #{venue}")
      sleep(0.1)
      self.city = venue.split(",").last&.strip
    end
  end

  def notify_attendees_if_cancelled
    if status_previously_changed? && status == "cancelled"
      orders.each do |order|
        UserMailer.event_cancelled(order.user, self).deliver_now
      end
    end
  end

  def update_search_index
    SearchIndexJob.perform_later(self.id) if saved_changes.any?
  end

  def send_organizer_confirmation
    UserMailer.event_created(user, self).deliver_now
  end

  def publish!
    update!(status: "published")
  end

  def cancel!
    update!(status: "cancelled")
  end
end

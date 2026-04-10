class Event < ApplicationRecord
  belongs_to :user
  has_many :ticket_tiers, dependent: :destroy
  has_many :orders
  has_many :bookmarks, dependent: :destroy

  validates :title, presence: true

  scope :published, -> { where(status: "published") }
  scope :upcoming, -> { where("starts_at > ?", Time.current) }

  after_update :notify_attendees_if_cancelled
  after_commit :update_search_index, on: :update
  after_create :send_organizer_confirmation
  after_commit :enqueue_geocode_if_venue_changed, on: [:create, :update]

  def total_tickets
    ticket_tiers.sum(:quantity)
  end

  def total_sold
    ticket_tiers.sum(:sold_count)
  end

  def sold_out?
    total_sold >= total_tickets
  end

  def enqueue_geocode_if_venue_changed
    return unless saved_change_to_venue?
    GeocodeVenueJob.perform_later(id)
  rescue StandardError => e
    Rails.logger.error("GeocodeVenueJob enqueue failed: #{e.message}")
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

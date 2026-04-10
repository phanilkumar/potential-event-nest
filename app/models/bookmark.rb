class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :event

  validates :user_id, uniqueness: { scope: :event_id, message: "already bookmarked this event" }
  validate  :only_attendees_can_bookmark

  private

  def only_attendees_can_bookmark
    errors.add(:base, "Only attendees can bookmark events") unless user&.attendee?
  end
end

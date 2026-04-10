class GeocodeVenueJob < ApplicationJob
  queue_as :default

  def perform(event_id)
    event = Event.find_by(id: event_id)
    return unless event&.venue.present?

    # Simulate external geocoding API call (blocking I/O happens here, off the web thread)
    Rails.logger.info("Geocoding venue: #{event.venue}")
    sleep(0.1)
    city = event.venue.split(",").last&.strip

    # Skip the callback to avoid re-enqueuing the job
    event.update_column(:city, city) if city.present?
  end
end

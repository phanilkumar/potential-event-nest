class SearchIndexJob < ApplicationJob
  queue_as :default

  def perform(event_id)
    event = Event.find_by(id: event_id)
    return unless event

    Rails.logger.info("Indexing event #{event_id}: #{event.title}")
  end
end

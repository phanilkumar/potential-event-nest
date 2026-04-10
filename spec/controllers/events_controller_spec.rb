require "rails_helper"

RSpec.describe Api::V1::EventsController, type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:other)     { create(:user, :organizer) }
  let(:attendee)  { create(:user) }

  def auth_headers(user)
    { "Authorization" => "Bearer #{user.generate_jwt}" }
  end

  describe "GET /api/v1/events" do
    it "returns published upcoming events" do
      create(:event, status: "published", starts_at: 1.week.from_now, ends_at: 1.week.from_now + 3.hours)
      create(:event, status: "draft", starts_at: 2.weeks.from_now, ends_at: 2.weeks.from_now + 3.hours)

      get "/api/v1/events"

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.length).to eq(1)
    end
  end

  describe "POST /api/v1/events" do
    it "creates an event" do
      post "/api/v1/events",
        params: { event: { title: "Test Event", description: "A test event",
                           venue: "Test Venue, Mumbai", starts_at: 1.week.from_now,
                           ends_at: 1.week.from_now + 3.hours, category: "conference" } },
        headers: auth_headers(attendee)

      expect(response).to have_http_status(:created)
    end
  end

  describe "PUT /api/v1/events/:id" do
    it "updates the event when it belongs to the current user" do
      event = create(:event, user: organizer)

      put "/api/v1/events/#{event.id}",
        params: { event: { title: "Updated Title" } },
        headers: auth_headers(organizer)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["title"]).to eq("Updated Title")
    end

    it "returns 404 when trying to update another user's event" do
      event = create(:event, user: organizer)

      put "/api/v1/events/#{event.id}",
        params: { event: { title: "Hacked" } },
        headers: auth_headers(other)

      expect(response).to have_http_status(:not_found)
      expect(event.reload.title).not_to eq("Hacked")
    end
  end

  describe "DELETE /api/v1/events/:id" do
    it "deletes the event when it belongs to the current user" do
      event = create(:event, user: organizer)

      delete "/api/v1/events/#{event.id}", headers: auth_headers(organizer)

      expect(response).to have_http_status(:no_content)
      expect(Event.exists?(event.id)).to be false
    end

    it "returns 404 when trying to delete another user's event" do
      event = create(:event, user: organizer)

      delete "/api/v1/events/#{event.id}", headers: auth_headers(other)

      expect(response).to have_http_status(:not_found)
      expect(Event.exists?(event.id)).to be true
    end
  end
end

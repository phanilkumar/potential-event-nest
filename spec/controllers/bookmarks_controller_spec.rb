require "rails_helper"

RSpec.describe Api::V1::BookmarksController, type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:attendee)  { create(:user) }
  let(:other)     { create(:user) }
  let(:event) do
    create(:event, user: organizer, status: "published",
           starts_at: 2.weeks.from_now, ends_at: 2.weeks.from_now + 3.hours)
  end

  def auth_headers(user)
    { "Authorization" => "Bearer #{user.generate_jwt}" }
  end

  # ── POST /api/v1/events/:event_id/bookmarks ──────────────────────────────
  describe "POST /api/v1/events/:event_id/bookmarks" do
    it "allows an attendee to bookmark an event" do
      post "/api/v1/events/#{event.id}/bookmarks", headers: auth_headers(attendee)

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["event_id"]).to eq(event.id)
    end

    it "returns 422 on duplicate bookmark" do
      create(:bookmark, user: attendee, event: event)

      post "/api/v1/events/#{event.id}/bookmarks", headers: auth_headers(attendee)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to include(match(/already bookmarked/))
    end

    it "returns 403 when an organizer tries to bookmark" do
      post "/api/v1/events/#{event.id}/bookmarks", headers: auth_headers(organizer)

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 when unauthenticated" do
      post "/api/v1/events/#{event.id}/bookmarks"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ── DELETE /api/v1/events/:event_id/bookmarks/:id ────────────────────────
  describe "DELETE /api/v1/events/:event_id/bookmarks/:id" do
    it "allows an attendee to remove their own bookmark" do
      bookmark = create(:bookmark, user: attendee, event: event)

      delete "/api/v1/events/#{event.id}/bookmarks/#{bookmark.id}",
             headers: auth_headers(attendee)

      expect(response).to have_http_status(:no_content)
      expect(Bookmark.exists?(bookmark.id)).to be false
    end

    it "returns 404 when bookmark does not belong to current user" do
      bookmark = create(:bookmark, user: other, event: event)

      delete "/api/v1/events/#{event.id}/bookmarks/#{bookmark.id}",
             headers: auth_headers(attendee)

      expect(response).to have_http_status(:not_found)
      expect(Bookmark.exists?(bookmark.id)).to be true
    end

    it "returns 404 when the bookmark id does not match the event" do
      # attendee has a bookmark on a different event — wrong :id in the URL
      other_event    = create(:event, user: organizer, status: "published",
                              starts_at: 3.weeks.from_now, ends_at: 3.weeks.from_now + 3.hours)
      other_bookmark = create(:bookmark, user: attendee, event: other_event)

      # supply correct event_id but wrong bookmark id (belongs to other_event)
      delete "/api/v1/events/#{event.id}/bookmarks/#{other_bookmark.id}",
             headers: auth_headers(attendee)

      expect(response).to have_http_status(:not_found)
      expect(Bookmark.exists?(other_bookmark.id)).to be true
    end

    it "returns 404 when bookmark does not exist" do
      delete "/api/v1/events/#{event.id}/bookmarks/99999",
             headers: auth_headers(attendee)

      expect(response).to have_http_status(:not_found)
    end
  end

  # ── GET /api/v1/bookmarks ─────────────────────────────────────────────────
  describe "GET /api/v1/bookmarks" do
    it "returns the attendee's bookmarked events" do
      create(:bookmark, user: attendee, event: event)

      get "/api/v1/bookmarks", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).map { |e| e["id"] }
      expect(ids).to include(event.id)
    end

    it "does not return events bookmarked by other users" do
      create(:bookmark, user: other, event: event)

      get "/api/v1/bookmarks", headers: auth_headers(attendee)

      ids = JSON.parse(response.body).map { |e| e["id"] }
      expect(ids).not_to include(event.id)
    end

    it "returns 403 when an organizer requests the list" do
      get "/api/v1/bookmarks", headers: auth_headers(organizer)

      expect(response).to have_http_status(:forbidden)
    end
  end

  # ── GET /api/v1/events/:event_id/bookmarks/count ─────────────────────────
  describe "GET /api/v1/events/:event_id/bookmarks/count" do
    it "returns the bookmark count to the event's organizer" do
      create(:bookmark, user: attendee, event: event)
      create(:bookmark, user: other,    event: event)

      get "/api/v1/events/#{event.id}/bookmarks/count",
          headers: auth_headers(organizer)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["bookmark_count"]).to eq(2)
    end

    it "returns 403 when a different organizer requests the count" do
      other_organizer = create(:user, :organizer)

      get "/api/v1/events/#{event.id}/bookmarks/count",
          headers: auth_headers(other_organizer)

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 when an attendee requests the count" do
      get "/api/v1/events/#{event.id}/bookmarks/count",
          headers: auth_headers(attendee)

      expect(response).to have_http_status(:forbidden)
    end
  end
end

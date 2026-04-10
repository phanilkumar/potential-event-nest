require "rails_helper"

RSpec.describe Api::V1::OrdersController, type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:attendee)  { create(:user) }
  let(:other)     { create(:user) }
  let(:event)     { create(:event, user: organizer, status: "published", starts_at: 2.weeks.from_now, ends_at: 2.weeks.from_now + 3.hours) }

  def auth_headers(user)
    { "Authorization" => "Bearer #{user.generate_jwt}" }
  end

  describe "GET /api/v1/orders" do
    it "returns only the current user's orders" do
      own_order   = create(:order, user: attendee, event: event)
      other_order = create(:order, user: other,    event: event)

      get "/api/v1/orders", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).map { |o| o["id"] }
      expect(ids).to include(own_order.id)
      expect(ids).not_to include(other_order.id)
    end
  end

  describe "GET /api/v1/orders/:id" do
    it "returns the order when it belongs to the current user" do
      order = create(:order, user: attendee, event: event)

      get "/api/v1/orders/#{order.id}", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
    end

    it "returns 404 when the order belongs to another user" do
      order = create(:order, user: other, event: event)

      get "/api/v1/orders/#{order.id}", headers: auth_headers(attendee)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/orders/:id/cancel" do
    it "cancels a pending order that belongs to the current user" do
      order = create(:order, user: attendee, event: event, status: "pending")

      post "/api/v1/orders/#{order.id}/cancel", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq("cancelled")
    end

    it "returns 404 when trying to cancel another user's order" do
      order = create(:order, user: other, event: event, status: "pending")

      post "/api/v1/orders/#{order.id}/cancel", headers: auth_headers(attendee)

      expect(response).to have_http_status(:not_found)
      expect(order.reload.status).to eq("pending")
    end
  end
end

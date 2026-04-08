require "rails_helper"

RSpec.describe Api::V1::OrdersController, type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:attendee) { create(:user) }
  let(:event) { create(:event, user: organizer, status: "published", starts_at: 2.weeks.from_now, ends_at: 2.weeks.from_now + 3.hours) }
  let(:tier) { create(:ticket_tier, event: event, quantity: 100, sold_count: 0) }

  def auth_headers(user)
    token = user.generate_jwt
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/orders" do
    it "returns orders" do
      create(:order, user: attendee, event: event)

      get "/api/v1/orders", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.length).to be >= 1
    end
  end

  describe "GET /api/v1/orders/:id" do
    it "returns order details" do
      order = create(:order, user: attendee, event: event)

      get "/api/v1/orders/#{order.id}", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/orders/:id/cancel" do
    it "cancels a pending order" do
      order = create(:order, user: attendee, event: event, status: "pending")

      post "/api/v1/orders/#{order.id}/cancel", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq("cancelled")
    end
  end
end

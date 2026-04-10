require "rails_helper"

RSpec.describe Api::V1::AuthController, type: :request do
  describe "POST /api/v1/auth/register" do
    let(:valid_params) do
      { name: "Alice", email: "alice@example.com",
        password: "password123", password_confirmation: "password123" }
    end

    it "registers a new user as attendee by default" do
      post "/api/v1/auth/register", params: valid_params

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["user"]["role"]).to eq("attendee")
    end

    it "ignores a user-supplied admin role" do
      post "/api/v1/auth/register", params: valid_params.merge(role: "admin")

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["user"]["role"]).to eq("attendee")
    end

    it "ignores a user-supplied organizer role" do
      post "/api/v1/auth/register", params: valid_params.merge(role: "organizer")

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["user"]["role"]).to eq("attendee")
    end
  end
end

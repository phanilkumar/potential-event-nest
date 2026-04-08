require "rails_helper"

RSpec.describe Order, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:event) }
    it { should have_many(:order_items) }
    it { should have_one(:payment) }
  end

  describe "validations" do
    it "validates status inclusion" do
      order = build(:order, status: "invalid")
      expect(order).not_to be_valid
    end
  end

  describe "#confirm!" do
    it "sets status to confirmed" do
      order = create(:order)
      order.confirm!
      expect(order.reload.status).to eq("confirmed")
    end
  end

  describe "#cancel!" do
    it "sets status to cancelled" do
      order = create(:order, status: "confirmed")
      order.cancel!
      expect(order.reload.status).to eq("cancelled")
    end
  end
end

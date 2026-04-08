require "rails_helper"

RSpec.describe TicketTier, type: :model do
  describe "associations" do
    it { should belong_to(:event) }
    it { should have_many(:order_items) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:price) }
    it { should validate_presence_of(:quantity) }
  end

  describe "#available_quantity" do
    it "calculates correctly" do
      tier = build(:ticket_tier, quantity: 100, sold_count: 30)
      expect(tier.available_quantity).to eq(70)
    end
  end

  describe "#reserve_tickets!" do
    it "increments sold_count" do
      tier = create(:ticket_tier, quantity: 100, sold_count: 0)
      tier.reserve_tickets!(5)
      expect(tier.reload.sold_count).to eq(5)
    end

    it "raises when not enough tickets" do
      tier = create(:ticket_tier, quantity: 10, sold_count: 8)
      expect { tier.reserve_tickets!(5) }.to raise_error(RuntimeError)
    end
  end
end

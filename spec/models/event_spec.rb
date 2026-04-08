require "rails_helper"

RSpec.describe Event, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:ticket_tiers) }
    it { should have_many(:orders) }
  end

  describe "validations" do
    it { should validate_presence_of(:title) }
  end

  describe "#sold_out?" do
    it "returns true when all tickets are sold" do
      event = create(:event)
      create(:ticket_tier, event: event, quantity: 10, sold_count: 10)

      expect(event.sold_out?).to be true
    end
  end

  describe "#total_tickets" do
    it "sums ticket quantities" do
      event = create(:event)
      create(:ticket_tier, event: event, quantity: 50)
      create(:ticket_tier, event: event, quantity: 100)

      expect(event.total_tickets).to eq(150)
    end
  end

  describe "scopes" do
    it "returns upcoming published events" do
      past_event = create(:event, starts_at: 1.week.ago, ends_at: 1.week.ago + 3.hours)
      future_event1 = create(:event, starts_at: 1.week.from_now, ends_at: 1.week.from_now + 3.hours)
      future_event2 = create(:event, starts_at: 2.weeks.from_now, ends_at: 2.weeks.from_now + 3.hours)
      draft_event = create(:event, starts_at: 3.weeks.from_now, status: "draft")

      results = Event.published.upcoming

      expect(results).to eq([future_event1, future_event2])
      expect(results).not_to include(past_event)
      expect(results).not_to include(draft_event)
    end
  end
end

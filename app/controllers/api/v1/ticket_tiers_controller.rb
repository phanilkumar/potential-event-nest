module Api
  module V1
    class TicketTiersController < ApplicationController
      skip_before_action :authenticate_user!, only: [:index]

      def index
        event = Event.find(params[:event_id])
        tiers = event.ticket_tiers

        render json: tiers.map { |t|
          {
            id: t.id,
            name: t.name,
            price: t.price.to_f,
            quantity: t.quantity,
            available: t.available_quantity,
            sales_start: t.sales_start,
            sales_end: t.sales_end
          }
        }
      end

      def create
        event = Event.find(params[:event_id])
        tier = event.ticket_tiers.build(tier_params)

        if tier.save
          render json: tier, status: :created
        else
          render json: { errors: tier.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        tier = TicketTier.find(params[:id])

        if tier.update(tier_params)
          render json: tier
        else
          render json: { errors: tier.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        tier = TicketTier.find(params[:id])
        tier.destroy
        head :no_content
      end

      private

      def tier_params
        params.require(:ticket_tier).permit(:name, :price, :quantity, :sold_count, :sales_start, :sales_end)
      end
    end
  end
end

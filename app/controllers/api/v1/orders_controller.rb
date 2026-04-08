module Api
  module V1
    class OrdersController < ApplicationController

      def index
        orders = Order.all.order(created_at: :desc)

        render json: orders.map { |order|
          {
            id: order.id,
            confirmation_number: order.confirmation_number,
            event: order.event.title,
            status: order.status,
            total_amount: order.total_amount.to_f,
            items_count: order.order_items.count,
            created_at: order.created_at
          }
        }
      end

      def show
        order = Order.find(params[:id])

        render json: {
          id: order.id,
          confirmation_number: order.confirmation_number,
          status: order.status,
          total_amount: order.total_amount.to_f,
          event: {
            id: order.event.id,
            title: order.event.title,
            starts_at: order.event.starts_at
          },
          items: order.order_items.map { |item|
            {
              ticket_tier: item.ticket_tier.name,
              quantity: item.quantity,
              unit_price: item.unit_price.to_f,
              subtotal: item.subtotal.to_f
            }
          },
          payment: order.payment ? {
            status: order.payment.status,
            provider_reference: order.payment.provider_reference
          } : nil
        }
      end

      def create
        event = Event.find(params[:event_id])

        order = Order.new(user: current_user, event: event)

        items_params = params.require(:items)
        items_params.each do |item_data|
          tier = TicketTier.find(item_data[:ticket_tier_id])

          order.order_items.build(
            ticket_tier: tier,
            quantity: item_data[:quantity].to_i,
            unit_price: tier.price
          )
        end

        if order.save
          order.payment.process!

          render json: {
            id: order.id,
            confirmation_number: order.confirmation_number,
            status: order.status,
            total_amount: order.total_amount.to_f,
            payment_status: order.payment.status
          }, status: :created
        else
          render json: { errors: order.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def cancel
        order = Order.find(params[:id])

        if order.status == "confirmed" || order.status == "pending"
          order.cancel!
          render json: { message: "Order cancelled", status: order.status }
        else
          render json: { error: "Cannot cancel order in #{order.status} status" }, status: :unprocessable_entity
        end
      end
    end
  end
end

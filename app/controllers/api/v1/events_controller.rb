module Api
  module V1
    class EventsController < ApplicationController
      SORT_COLUMNS = %w[starts_at ends_at title created_at].freeze

      skip_before_action :authenticate_user!, only: [:index, :show]

      def index
        events = Event.published.upcoming.includes(:user, :ticket_tiers)

        if params[:search].present?
          events = events.where("title LIKE :search OR description LIKE :search", search: "%#{params[:search]}%")
        end

        if params[:category].present?
          events = events.where(category: params[:category])
        end

        if params[:city].present?
          events = events.where(city: params[:city])
        end

        sort_col, sort_dir = params[:sort_by].to_s.split
        sort_col = SORT_COLUMNS.include?(sort_col) ? sort_col : "starts_at"
        sort_dir = sort_dir&.upcase == "DESC" ? "DESC" : "ASC"
        events = events.order("#{sort_col} #{sort_dir}")

        render json: events.map { |event|
          {
            id: event.id,
            title: event.title,
            description: event.description,
            venue: event.venue,
            city: event.city,
            starts_at: event.starts_at,
            ends_at: event.ends_at,
            category: event.category,
            organizer: event.user.name,
            total_tickets: event.total_tickets,
            tickets_sold: event.total_sold,
            ticket_tiers: event.ticket_tiers.map { |t|
              {
                id: t.id,
                name: t.name,
                price: t.price.to_f,
                available: t.available_quantity
              }
            }
          }
        }
      end

      def show
        event = Event.includes(:user, :ticket_tiers).find(params[:id])

        render json: {
          id: event.id,
          title: event.title,
          description: event.description,
          venue: event.venue,
          city: event.city,
          starts_at: event.starts_at,
          ends_at: event.ends_at,
          status: event.status,
          category: event.category,
          organizer: {
            id: event.user.id,
            name: event.user.name
          },
          ticket_tiers: event.ticket_tiers.map { |t|
            {
              id: t.id,
              name: t.name,
              price: t.price.to_f,
              quantity: t.quantity,
              sold: t.sold_count,
              available: t.available_quantity
            }
          }
        }
      end

      def create
        event = Event.new(event_params)
        event.user = current_user

        if event.save
          render json: event, status: :created
        else
          render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        event = current_user.events.find(params[:id])

        if event.update(event_params)
          render json: event
        else
          render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        event = current_user.events.find(params[:id])
        event.destroy
        head :no_content
      end

      private

      def event_params
        params.require(:event).permit(:title, :description, :venue, :city,
          :starts_at, :ends_at, :category, :max_capacity, :status)
      end
    end
  end
end

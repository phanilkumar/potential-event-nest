module Api
  module V1
    class BookmarksController < ApplicationController

      # POST /api/v1/events/:event_id/bookmarks
      def create
        unless current_user.attendee?
          return render json: { error: "Only attendees can bookmark events" }, status: :forbidden
        end

        event    = Event.find(params[:event_id])
        bookmark = current_user.bookmarks.build(event: event)

        if bookmark.save
          render json: { message: "Event bookmarked", event_id: event.id }, status: :created
        else
          render json: { errors: bookmark.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/events/:event_id/bookmarks/:id
      def destroy
        bookmark = current_user.bookmarks.find_by(id: params[:id], event_id: params[:event_id])

        if bookmark
          bookmark.destroy
          head :no_content
        else
          render json: { error: "Bookmark not found" }, status: :not_found
        end
      end

      # GET /api/v1/bookmarks — attendee's own bookmark list
      def index
        unless current_user.attendee?
          return render json: { error: "Only attendees can view their bookmarks" }, status: :forbidden
        end

        events = current_user.bookmarked_events
                              .includes(:user, :ticket_tiers)
                              .order("bookmarks.created_at DESC")

        render json: events.map { |event|
          {
            id:          event.id,
            title:       event.title,
            venue:       event.venue,
            city:        event.city,
            starts_at:   event.starts_at,
            category:    event.category,
            organizer:   event.user.name
          }
        }
      end

      # GET /api/v1/events/:event_id/bookmarks/count — organizer only
      def count
        event = Event.find(params[:event_id])

        unless current_user.organizer? && event.user_id == current_user.id
          return render json: { error: "Only the event organizer can view bookmark counts" }, status: :forbidden
        end

        render json: { event_id: event.id, bookmark_count: event.bookmarks.count }
      end
    end
  end
end

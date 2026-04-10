Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"

      resources :events do
        resources :ticket_tiers, only: [:index, :create, :update, :destroy]
        resources :bookmarks,    only: [:create, :destroy] do
          collection do
            get :count
          end
        end
      end

      resources :orders, only: [:index, :show, :create] do
        member do
          post :cancel
        end
      end

      # GET /api/v1/bookmarks — attendee's own bookmarked events list
      get "bookmarks", to: "bookmarks#index"
    end
  end
end

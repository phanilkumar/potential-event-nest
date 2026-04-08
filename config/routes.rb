Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"

      resources :events do
        resources :ticket_tiers, only: [:index, :create, :update, :destroy]
      end

      resources :orders, only: [:index, :show, :create] do
        member do
          post :cancel
        end
      end
    end
  end
end

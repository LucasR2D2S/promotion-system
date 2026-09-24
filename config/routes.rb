Rails.application.routes.draw do
  # Health check for load balancers / uptime monitors (200 if the app boots, 500 otherwise).
  get "up" => "rails/health#show", as: :rails_health_check

  root 'home#index'

  devise_for :users
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  get 'search', to:"promotions#search"
  
  resources :promotions, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    member do 
      post 'generate_coupons'
      post 'approve'
      post 'marketing_copy'
      # get 'search', to:"promotions#search"
    end
  end

  resources :coupons, only: [] do
    post 'disable', on: :member
    post 'able', on: :member
  end

  resources :categories, only: [:index, :show, :new, :create, :edit, :update, :destroy]

  # Checkout API for storefronts (JSON, bearer token). The order reference is part
  # of the URL, so it may contain dots: no format suffix parsing.
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :quotes, only: :create
      resources :redemptions, only: %i[create show destroy], param: :order_reference,
                              constraints: { order_reference: %r{[^/]+} }, format: false
    end
  end
  # Exemplo de uma rota customizada:
  # post '/promotions/:id/generate', to: 'promotion#generate_coupons', as: :generate_coupons
end

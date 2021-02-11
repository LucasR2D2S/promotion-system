Rails.application.routes.draw do
  root 'home#index'

  devise_for :users
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  get 'search', to:"promotions#search"
  
  resources :promotions, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    member do 
      post 'generate_coupons'
      post 'approve'
      # get 'search', to:"promotions#search"
    end
  end

  resources :coupons, only: [] do
    post 'disable', on: :member
    post 'able', on: :member
  end

  resources :categories, only: [:index, :show, :new, :create, :edit, :update] do
  end
  # Exemplo de uma rota customizada:
  # post '/promotions/:id/generate', to: 'promotion#generate_coupons', as: :generate_coupons
end

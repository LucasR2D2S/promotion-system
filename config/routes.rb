Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root 'home#index'
  resources :promotions, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    post 'generate_coupons', on: :member
  end
  # Exemplo de uma rota customizada:
  # post '/promotions/:id/generate', to: 'promotion#generate_coupons', as: :generate_coupons
end

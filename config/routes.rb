Rails.application.routes.draw do
  # The API is versioned from the first commit: other tools depend on this
  # contract, and the way to change it is to add v2, not to edit v1.
  namespace :api do
    namespace :v1 do
      resources :palettes, only: %i[ index show create update destroy ] do
        get :colors, on: :member
      end

      resources :colors, only: %i[ index show create ]
    end
  end

  resource :lookup, only: :show, controller: :lookups
  resources :colors, only: %i[ index show ]
  resources :palettes do
    resources :colors, only: %i[ new create ], controller: "palettes/colors"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "palettes#index"
end

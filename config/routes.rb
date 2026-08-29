Rails.application.routes.draw do
  # The API is versioned from the first commit: other tools depend on this
  # contract, and the way to change it is to add v2, not to edit v1.
  namespace :api do
    namespace :v1 do
      resources :palettes, only: %i[ index show create update destroy ] do
        get :colors, on: :member
      end

      resources :colors, only: %i[ index show create update destroy ]
    end
  end

  # The human side. Colors are only ever created in the context of a palette
  # or read on their own; the API is the place for bulk work.
  resources :palettes do
    resource :tags, only: %i[ edit update ], controller: "palettes/tags"

    resources :colors, only: %i[ new create destroy ], controller: "palettes/colors" do
      patch :move, on: :member
    end
  end

  resources :colors, only: %i[ index new create show edit update destroy ] do
    resource :tags, only: %i[ edit update ], controller: "colors/tags"
  end
  resource :lookup, only: :show

  get "up" => "rails/health#show", as: :rails_health_check

  root "palettes#index"
end

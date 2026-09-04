Pandatone::Engine.routes.draw do
  # The API is versioned from the first commit: other tools depend on this
  # contract, and the way to change it is to add v2, not to edit v1.
  #
  # JSON by default, so a request that names no format gets the one this API
  # published itself as. An explicit .ase or .css still wins over the default,
  # which is how a palette can be fetched as a file on the same route.
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      # The API describes itself, and the description is not behind the token:
      # a tool has to be able to read the door before it has a key.
      get "openapi", to: "openapi#show", as: :openapi

      resources :palettes, only: %i[ index show create update destroy ] do
        get :colors, on: :member
      end

      resources :colors, only: %i[ index show create update destroy ]

      # The lookup screen's answer, and the tags a client needs to build the
      # same filters the interface offers.
      resource :lookup, only: :show
      resources :tags, only: :index
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

  root "palettes#index"
end

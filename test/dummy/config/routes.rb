Rails.application.routes.draw do
  mount Pandatone::Engine => "/pandatone"

  # Somewhere public to land on, so a browser test can plant its cookie
  # before it reaches the engine.
  root "home#show"
end

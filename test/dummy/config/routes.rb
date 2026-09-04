Rails.application.routes.draw do
  mount Pandatone::Engine => "/pandatone"

  # Something public to land on, so a browser test can plant its cookie
  # before it reaches the engine.
  root to: proc { [ 200, { "content-type" => "text/html" }, [ "<!doctype html><title>Dummy</title>" ] ] }
end

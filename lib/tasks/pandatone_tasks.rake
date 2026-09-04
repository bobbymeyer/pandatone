namespace :pandatone do
  desc "Plant a small but real library, so a host has something to look at. Idempotent."
  task seed: :environment do
    Pandatone::Seeds.plant
  end
end

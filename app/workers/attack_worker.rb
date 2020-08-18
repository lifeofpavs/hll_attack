class AttackWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker
  sidekiq_options queue: :attack, retry: false, backtrace: true

  def perform(attack_vector, currentCardinality)
    puts "Attacke vector is #{attack_vector}"
    puts currentCardinality
    Api::AttackController.new(attack_vector, currentCardinality).populate_conversions
  end
end
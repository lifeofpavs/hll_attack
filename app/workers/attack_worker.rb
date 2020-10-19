class AttackWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker
  sidekiq_options queue: :attack, retry: false, backtrace: true

  def perform(attack_vector, currentCardinality)
    Api::AttackController.new(attack_vector, currentCardinality).all
  end
end
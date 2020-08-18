module Api
  class SimulationController < ApplicationController
    def start_attack
      length = params[:attack_length]
      puts params[:current_cardinality]
      data = AttackWorker.perform_async(length, params[:current_cardinality])
      render :json => { code: 200, msg: "Okay", jid: data}
    end
  end
end
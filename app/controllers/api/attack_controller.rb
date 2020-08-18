module Api
  class AttackController < ApplicationController
      
    def initialize(attack_length, currentCardinality)
      puts currentCardinality
      @expectedCardinality = attack_length.to_i
      @currentCardinality = currentCardinality.to_i
      @oldCardinality 
      @attack_vector = []
    end
  
    def reset
      #Reset conversions table 
      Conversion.delete_all
      ActiveRecord::Base.connection.execute("Truncate table summary_test ")
    end
  
    def populate_conversions
      start = Time.now
      Utils::Slack::HllBot.send_message("Starting simulation at #{start} with *#{@expectedCardinality}* ", "simulations")
      #Populate and check cardinality

      #reset
      conversion_id = @currentCardinality
      while @currentCardinality < @expectedCardinality do 
        oldCardinality = @currentCardinality
        Conversion.create(conversion_id: conversion_id, conversion_date: "2020-03-19", user_id: 1)
        @currentCardinality = Utils::PrestoDb.new.get_cardinality
        if @currentCardinality > oldCardinality  
          @attack_vector << conversion_id
        end
        conversion_id += 1
      end
      
      puts "Attack Vector is #{@attack_vector}"

      @attack_vector.each do |attack_number|
        AttackVector.create(number: attack_number)
      end

      finish = Time.now
      diff = finish - start
      Utils::Slack::HllBot.send_message("Finished simulation at #{finish} with *#{@expectedCardinality}* ", "simulations")
      Utils::Slack::HllBot.send_message("Took #{diff} seconds to complete. Total size of attack_vector is #{@attack_vector.size}", "simulations")
      Execution.create(time: diff.to_s, vector_size: @attack_vector.size)
      Utils::Slack::HllBot.send_message("Cardinality for #{@expectedCardinality} elements is #{Utils::PrestoDb.new.get_cardinality}", "simulations")
      Utils::Slack::HllBot.send_message("Cardinality for Attack Vector with #{AttackVector.all.count} elements is #{Utils::PrestoDb.new.get_cardinality_attack_vector}", "simulations")
      error = (Utils::PrestoDb.new.get_cardinality - Utils::PrestoDb.new.get_cardinality_attack_vector).to_i
      Utils::Slack::HllBot.send_message("Error is #{error} of #{(error * 100)/@expectedCardinality.to_i}%", "simulations")
      
      
    end

    def attack_hll
      @oldCardinality = @currentCardinality
      reset
      @attack_vector.each do |conversion_id|
        Conversion.create(conversion_id: conversion_id, conversion_date: "2020-03-19", user_id: 1)
      end
      puts "Final cardinality is: #{Utils::PrestoDb.new.get_cardinality}"
    end

  end
end
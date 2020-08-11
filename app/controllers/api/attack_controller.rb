module Api
  class AttackController < ApplicationController
    before_action :initial_values
  
    def reset
      #Reset conversions table 
      Conversion.delete_all
      ActiveRecord::Base.connection.execute("Truncate table summary_test ")
    end
  
    def populate_conversions
      start = Time.now
      #Populate and check cardinality
      initial_values
      reset
      conversion_id = 0
      while conversion_id < @expectedCardinality do 
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
      Execution.create(time: diff.to_s, vector_size: @attack_vector.size)
    end

    def attack_hll
      @oldCardinality = @currentCardinality
      reset
      @attack_vector.each do |conversion_id|
        Conversion.create(conversion_id: conversion_id, conversion_date: "2020-03-19", user_id: 1)
      end
      puts "Final cardinality is: #{Utils::PrestoDb.new.get_cardinality}"
    end

  
    def initial_values
      @expectedCardinality = 20000
      @currentCardinality = 0
      @oldCardinality 
      @attack_vector = []
    end
  
  end
end
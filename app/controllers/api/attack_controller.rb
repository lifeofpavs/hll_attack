module Api
  class AttackController < ApplicationController
      
    #This controller will hold the main functionality of the attack. 
    #It is divided in 3 phases
      #Phase 1: Will insert the initial elements and create the initial attack vector
      #Phase 2: Due to the deterministic nature of HLL, some elements will be missed, so this phase aims to insert all missed elements into the attack vector
      #Phase 3: This final phase will filter the attack vector, only leaving in it those that realy increase the cardinality

    def initialize(expectedCardinality, currentCardinality)
      @expectedCardinality = expectedCardinality.to_i
      @currentCardinality = currentCardinality.to_i
      @oldCardinality = 0 
      @attack_vector = []
    end
  
    def reset
      #Reset the database to perform a new experiment
      Conversion.delete_all
      ConversionFase2.delete_all
      ConversionFiltered.delete_all
      AttackVector.delete_all
      AttackVectorFase2.delete_all
      AttackVectorFiltered.delete_all
      ActiveRecord::Base.connection.execute("Truncate table conversions ")
      ActiveRecord::Base.connection.execute("Truncate table conversion_fase2s")
      ActiveRecord::Base.connection.execute("Truncate table conversion_filtereds ")
      ActiveRecord::Base.connection.execute("Truncate table attack_vectors ")
      ActiveRecord::Base.connection.execute("Truncate table attack_vector_fase2s ")
      ActiveRecord::Base.connection.execute("Truncate table attack_vector_filtereds ")
      ActiveRecord::Base.connection.execute("Truncate table summary_test ")
      ActiveRecord::Base.connection.execute("Truncate table summary_conversions ")
    end
  
    def fase1 #Phase 1 - Insert elements until expectedCardinality elements and compute attack vector of phase 1 with those that increase the cardinality
      start = Time.now
      Utils::Slack::HllBot.send_message("Starting simulation at #{start} with *#{@expectedCardinality}* ", "simulations")

      #Populate and check cardinality
      #Insert elements up to expectedCardinality
      for i in 0...@expectedCardinality do 
        oldCardinality = @currentCardinality #Get cardinality before insertion

        puts "ID: #{i}"
        data = Conversion.create(conversion_id: i, conversion_date: "2020-03-19", user_id: 1) #Insert new element
        puts "DAta id is : #{data.id}"
        @currentCardinality = Utils::PrestoDb.new.get_cardinality(data.id) #Get new cardinality

        if @currentCardinality > oldCardinality  #If new cardinality is gretater than old cardinality, insert in attack vector
          AttackVector.create(number: i)
        end

      end
      
      finish = Time.now
      diff = finish - start

      Utils::Slack::HllBot.send_message("Finished simulation at #{finish} with *#{@expectedCardinality}* ", "simulations")
      Utils::Slack::HllBot.send_message("Took #{diff} seconds to complete. Total size of attack_vector is #{AttackVector.all.count}", "simulations")
      Execution.create(time: diff.to_s, vector_size: AttackVector.all.count)
      Utils::Slack::HllBot.send_message("Cardinality for #{@expectedCardinality} elements is #{@currentCardinality}", "simulations")
      Utils::Slack::HllBot.send_message("Cardinality for Attack Vector with #{AttackVector.all.count} elements is #{Utils::PrestoDb.new.get_cardinality_attack_vector("attack_vectors")}", "simulations")
      
    end

    def fase2 #Phase 2 - Insert all missed elements in new attack vector. Creating a new attack vector in order to have better tracking between phases
     
      start = Time.now
      Utils::Slack::HllBot.send_message("Starting simulation fase 2  at #{start} with *#{@expectedCardinality}* ", "simulations")

      actual_attack_vector = AttackVector.all.pluck(:number).uniq #Get uniq elements in attack vector
      conversions = [*0...@expectedCardinality] #Populate array with elements from 1 to expectedCardinality

      #In order to get a new HLL, the old one should be emptied
      ActiveRecord::Base.connection.execute("Truncate table summary_test ")

      #Insert elements in the attack vector to be used in this phase
      AttackVector.all.each do |vector_item|
        ConversionFase2.create(conversion_id: vector_item.number, conversion_date: "2020-03-19", user_id: 1)
        AttackVectorFase2.create(number: vector_item.number)
      end

      Utils::PrestoDb.new.insert_all_element_presto_fase2 #Insert all elements in the HLL

      #Obtain actual cardinality after inserting initial elements 
      oldCardinality = Utils::PrestoDb.new.get_cardinality_fase2

      #Get final array of elements not included
      conversions_2 = conversions.select { |e| !(actual_attack_vector.include? (e))} #Perform except in order to get elements not in attack vector 
      puts "Done getting elements not in array. Length #{conversions_2.size}"
      conversions_2.each do |conversion_id| #Insert the elements, if the cardinality increases, it is a missed element and should be added to the attack vector
        oldCardinality = @currentCardinality
        puts "ID: #{conversion_id}"
        data = ConversionFase2.create(conversion_id: conversion_id, conversion_date: "2020-03-19", user_id: 1)
        Utils::PrestoDb.new.insert_element_presto_fase2(data.id)
        @currentCardinality = Utils::PrestoDb.new.get_cardinality_fase2

        if @currentCardinality > oldCardinality  
          AttackVectorFase2.create(number: conversion_id)
        end
        
      end

      finish = Time.now
      diff = finish - start

      Utils::Slack::HllBot.send_message("Finished simulation fase 2 at #{finish} with *#{@expectedCardinality}* ", "simulations")
      Utils::Slack::HllBot.send_message("Took #{diff} seconds to complete. Total size of attack_vector is #{AttackVectorFase2.all.count}", "simulations")
      Execution.create(time: diff.to_s, vector_size: AttackVectorFase2.all.count)
      Utils::Slack::HllBot.send_message("Cardinality for #{@expectedCardinality} elements is #{@currentCardinality}", "simulations")
      Utils::Slack::HllBot.send_message("Cardinality for Attack Vector with #{AttackVectorFase2.all.count} elements is #{Utils::PrestoDb.new.get_cardinality_attack_vector("attack_vector_fase2s")}", "simulations")
      
    end

    def fase3(filtered = false) #Fase 3  Insert elements in descending order 
      start = Time.now
      Utils::Slack::HllBot.send_message("Starting simulation at #{start} with *#{@expectedCardinality}* ", "simulations")

      #In order to obtain a new HLL, we have to empty the previous one 
      ActiveRecord::Base.connection.execute("Truncate table summary_test")

      conversion_ids = AttackVectorFase2.order(number: :desc)
      @currentCardinality = 0 #As the HLL is new, the current cardinality of it, would be 0
      oldCardinality = 0

      #The elements will be inserted in descending order
      #If the cardinality increases, the element will be added to the attack vector
      conversion_ids.each do |conversion_id|
        oldCardinality = @currentCardinality

        puts "ID: #{conversion_id.number}"
        data = ConversionFiltered.create(conversion_id: conversion_id.number, conversion_date: "2020-06-13", user_id: 1) #Insert new element 

        @currentCardinality = Utils::PrestoDb.new.get_cardinality_filtered(data.id) #Get cardinality of filtered set 

        if@currentCardinality > oldCardinality  #If increases, insert in attack vector
          AttackVectorFiltered.create(number: conversion_id.number)
        end
      end

      finish = Time.now
      diff = finish - start
      Utils::Slack::HllBot.send_message("Finished simulation fase 2 at #{finish} with *#{@expectedCardinality}* ", "simulations")
      Utils::Slack::HllBot.send_message("Took #{diff} seconds to complete. Total size of attack_vector is #{AttackVectorFase2.all.count}", "simulations")
      Execution.create(time: diff.to_s, vector_size: AttackVectorFiltered.all.count)
      Utils::Slack::HllBot.send_message("Cardinality for #{@expectedCardinality} elements is #{@currentCardinality}", "simulations")
      Utils::Slack::HllBot.send_message("Cardinality for Attack Vector with #{AttackVectorFiltered.all.count} elements is #{Utils::PrestoDb.new.get_cardinality_attack_vector("attack_vector_filtereds")}", "simulations")
      
    end

    #Execute all the phases of the attack after resetting the database
    def all
      reset
      fase1
      fase2
      fase3
    end

  end
end
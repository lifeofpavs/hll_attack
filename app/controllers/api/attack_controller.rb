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
  
    def fase1 #Fase 1 
      #Cardinalidad no tiene que ser 100k, si no que tenemos que meter 100k elementos y la cardinalidad, la que sea 
      start = Time.now
      Utils::Slack::HllBot.send_message("Starting simulation at #{start} with *#{@expectedCardinality}* ", "simulations")

      #Populate and check cardinality

      #Keep populating until desired cardinality is achieved
      for i in 0...@expectedCardinality do 
        oldCardinality = @currentCardinality #Get cardinality before insertion

        puts "ID: #{i}"
        Conversion.create(conversion_id: i, conversion_date: "2020-03-19", user_id: 1) #Insert new element

        @currentCardinality = Utils::PrestoDb.new.get_cardinality #Get new cardinality

        if @currentCardinality > oldCardinality  #If new cardinality is gretater than old cardinality, insert in attack vector
          AttackVector.create(number: i)
        end

      end
      
      finish = Time.now
      diff = finish - start

      Utils::Slack::HllBot.send_message("Finished simulation at #{finish} with *#{@expectedCardinality}* ", "simulations")
      Utils::Slack::HllBot.send_message("Took #{diff} seconds to complete. Total size of attack_vector is #{@attack_vector.size}", "simulations")
      Execution.create(time: diff.to_s, vector_size: AttackVector.all.count)
      Utils::Slack::HllBot.send_message("Cardinality for #{@expectedCardinality} elements is #{Utils::PrestoDb.new.get_cardinality}", "simulations")
      Utils::Slack::HllBot.send_message("Cardinality for Attack Vector with #{AttackVector.all.count} elements is #{Utils::PrestoDb.new.get_cardinality_attack_vector}", "simulations")
      error = (Utils::PrestoDb.new.get_cardinality - Utils::PrestoDb.new.get_cardinality_attack_vector).to_i
      Utils::Slack::HllBot.send_message("Error is #{error} of #{(error * 100)/@expectedCardinality.to_i}%", "simulations")
      
    end

    def fase2 #Fase2
      #Crear una nueva coleccion de AttackVecgor --> AttackVectorFase2 
      #Get elements not in db 
      actual_attack_vector = AttackVector.all.pluck(:number).uniq #Get uniq elements in attack vector
      conversions = [*36630..@expectedCardinality] #Populate array with elements from 1 to 100k

      #New HLL | Resetear el summary_test
      ActiveRecord::Base.connection.execute("Truncate table summary_test ")
      #Meter elementos en vector de ataque primero
      AttackVector.all.each do |vector_item|
        ConversionFase2.create(conversion_id: vector_item.number, conversion_date: "2020-03-19", user_id: 1)
      end
      Utils::PrestoDb.new.insert_all_element_presto_fase2
      puts "Done injecting fase2 attack vector"
      #Sacar cardinalidad 
      oldCardinality = Utils::PrestoDb.new.get_cardinality_fase2
      #Injectar uno a uno los que no estaban en el vector de ataque y ver los que aumentan la cardinalidad 
      #Si aumenta, meter en el vector de ataque 

      #Get final array of elements
      conversions_2 = conversions.select { |e| !(actual_attack_vector.include? (e))} #Perform except in order to get elements not in attack vector 
      puts "Done getting elements not in array. Length #{conversions_2.size}"
      conversions_2.each do |conversion_id| #Same as populate_conversions

        puts "ID: #{conversion_id}"
        ConversionFase2.create(conversion_id: conversion_id, conversion_date: "2020-03-19", user_id: 1)
        Utils::PrestoDb.new.insert_element_presto_fase2
        @currentCardinality = Utils::PrestoDb.new.get_cardinality_fase2

        if @currentCardinality > oldCardinality  
          AttackVectorFase2.create(number: conversion_id)
        end
        oldCardinality = @currentCardinality
      end

    end

    def fase3(filtered = false) #Fase 3  Insertar de mayor a menor 
      start = Time.now
      Utils::Slack::HllBot.send_message("Starting simulation at #{start} with *#{@expectedCardinality}* ", "simulations")

      #New HLL | Truncar el antiguo
      ActiveRecord::Base.connection.execute("Truncate table summary_test ")

      conversion_ids = filtered ? AttackVectorFiltered.all.order("number desc") : AttackVector.all.order("number desc") #If one filtering round has been done, get AttackVectorFiltered, where tthe filtered elements are
      currentCardinality = Utils::PrestoDb.new.get_cardinality_filtered || 0 #Get current cardinality of filtered elements. 0 if null
      oldCardinality = 0

      #Meter los elementos en order inverso
      #Si aumenta cardinalidad, guardar en vector de ataque final

      conversion_ids.each do |conversion_id|
        oldCardinality = currentCardinality

        puts "ID: #{conversion_id.number}"
        ConversionFiltered.create(conversion_id: conversion_id.number, conversion_date: "2020-06-13", user_id: 1) #Insert new element 

        currentCardinality = Utils::PrestoDb.new.get_cardinality_filtered #Get cardinality of filtered set 

        if currentCardinality > oldCardinality  #If increases, insert in attack vector
          AttackVectorFiltered.where(number: conversion_id.number).first_or_create
        else #Else, delete it 
          AttackVectorFiltered.find_by(number: conversion_id.number).delete if filtered
        end
      end

      finish = Time.now
      diff = finish - start
      Utils::Slack::HllBot.send_message("Finished filtering at #{finish} with *#{conversion_ids.count}* ", "simulations")
      Utils::Slack::HllBot.send_message("Took #{diff} seconds to complete. Total size of attack_vector is #{AttackVectorFiltered.all.count}", "simulations")
      Execution.create(time: diff.to_s, vector_size: AttackVectorFiltered.all.count)
    end

    def all
      fase1
      fase2
      fase3
    end

  end
end
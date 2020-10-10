module Api
  class AttackController < ApplicationController
      
    def initialize(attack_length, currentCardinality)
      @expectedCardinality = attack_length.to_i
      @currentCardinality = currentCardinality.to_i
      @oldCardinality = 0 
      @attack_vector = []
    end
  
    def reset
      #Reset conversions table 
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
  
    def fase1 #Fase 1 
      #Cardinalidad no tiene que ser 100k, si no que tenemos que meter 100k elementos y la cardinalidad, la que sea 
      start = Time.now
      Utils::Slack::HllBot.send_message("Starting simulation at #{start} with *#{@expectedCardinality}* ", "simulations")

      #Populate and check cardinality

      #Keep populating until desired cardinality is achieved
      for i in 71054...@expectedCardinality do 
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

    def fase2 #Fase2
      #Crear una nueva coleccion de AttackVecgor --> AttackVectorFase2 
      #Get elements not in db 
      start = Time.now
      Utils::Slack::HllBot.send_message("Starting simulation fase 2  at #{start} with *#{@expectedCardinality}* ", "simulations")

      actual_attack_vector = AttackVector.all.pluck(:number).uniq #Get uniq elements in attack vector
      conversions = [*30090...@expectedCardinality] #Populate array with elements from 1 to 100k

      #New HLL | Resetear el summary_test
      ActiveRecord::Base.connection.execute("Truncate table summary_test ")
      #Meter elementos en vector de ataque primero
      # AttackVector.all.each do |vector_item|
      #   ConversionFase2.create(conversion_id: vector_item.number, conversion_date: "2020-03-19", user_id: 1)
      #   AttackVectorFase2.create(number: vector_item.number)
      # end

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

    def fase3(filtered = false) #Fase 3  Insertar de mayor a menor 
      start = Time.now

      Utils::Slack::HllBot.send_message("Starting simulation at #{start} with *#{@expectedCardinality}* ", "simulations")

      #New HLL | Truncar el antiguo
      ActiveRecord::Base.connection.execute("Truncate table summary_test")

      conversion_ids = AttackVectorFase2.order(number: :desc) #If one filtering round has been done, get AttackVectorFiltered, where tthe filtered elements are
      @currentCardinality = 0 #Get current cardinality of filtered elements. 0 if null
      oldCardinality = 0

      #Meter los elementos en order inverso
      #Si aumenta cardinalidad, guardar en vector de ataque final

      conversion_ids.each do |conversion_id|
        oldCardinality = @currentCardinality

        puts "ID: #{conversion_id.number}"
        data = ConversionFiltered.create(conversion_id: conversion_id.number, conversion_date: "2020-06-13", user_id: 1) #Insert new element 

        @currentCardinality = Utils::PrestoDb.new.get_cardinality_filtered(data.id) #Get cardinality of filtered set 

        if@currentCardinality > oldCardinality  #If increases, insert in attack vector
          AttackVectorFiltered.create(number: conversion_id.number)
        # else #Else, delete it 
        #   AttackVectorFiltered.find_by(number: conversion_id.number).delete if filtered
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

    def all
      # reset
      # fase1
      fase2
      # fase3
    end

  end
end
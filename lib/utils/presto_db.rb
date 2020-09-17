require 'presto-client'
module Utils
  class PrestoDb 
    def initialize
      # create a client object:
      @client = Presto::Client.new(
        server: "localhost:8080",   # required option
        ss: {verify: false},
        catalog: "mysql",
        schema: "test",
        user: "root",
        time_zone: "US/Pacific",
        language: "English"
      )
    end

    def get_cardinality(id)
      #Insertar uno a uno en lugar de el total  
      @client.run("insert into summary_test (select cast(approx_set(conversion_id) as varbinary) as conversion_hll_sketch, conversion_date from conversions where id=#{id} group by conversion_date)")
      columns, rows = @client.run("select cardinality(merge(cast(hll as HyperLogLog))) as daily_conversions from summary_test")
      puts "Cardinality: #{rows}"
      rows[0][0]
    end

    def get_cardinality_fase2
      #Insertar uno a uno en lugar de el total  
      columns, rows = @client.run("select cardinality(merge(cast(hll as HyperLogLog))) as daily_conversions from summary_test")
      puts "Cardinality: #{rows}"
      rows[0][0]
    end

    def insert_element_presto_fase2(id)
      @client.run("insert into summary_test (select cast(approx_set(conversion_id) as varbinary) as conversion_hll_sketch, conversion_date from conversion_fase2s where id = #{id} group by conversion_date)")
    end

    def insert_all_element_presto_fase2
      @client.run("insert into summary_test (select cast(approx_set(conversion_id) as varbinary) as conversion_hll_sketch, conversion_date from conversion_fase2s group by conversion_date)")
    end

    def get_cardinality_filtered(id)
      puts "ID is #{id}"
      @client.run("insert into summary_test (select cast(approx_set(conversion_id) as varbinary) as conversion_hll_sketch, conversion_date from conversion_filtereds where id = #{id} group by conversion_date)")
      columns, rows = @client.run("select cardinality(merge(cast(hll as HyperLogLog))) as daily_conversions from summary_test")
      puts "Cardinality filtered: #{rows}"
      rows[0][0]
    end

    def get_cardinality_attack_vector
      # run a query and get results as an array of arrays:
      #ActiveRecord::Base.connection.execute("Truncate table summary_test")
      #Building cardinality
      
      @client.run("insert into summary_conversions select cast(approx_set(number) as varbinary) as conversion_hll_sketch from attack_vectors ")
      #Get cardinality
      columns, rows = @client.run("select cardinality(merge(cast(hll as HyperLogLog))) as daily_conversions from summary_conversions")
      #Return cardinality
      puts "Cardinality: #{rows}"
      rows[0][0]
    end

    def normal_order(database)
      range = 20000
      while range < 100001 do
        ActiveRecord::Base.connection.execute("Truncate table summary_conversions ")
        @client.run("insert into summary_conversions select cast(approx_set(number) as varbinary) as conversion_hll_sketch from #{database}  where number < #{range} group by number")
        columns, rows = @client.run("select cardinality(merge(cast(hll as HyperLogLog))) as daily_conversions from summary_conversions")
        #Return cardinality
        puts "Cardinality for #{range}: #{rows}"
        ActiveRecord::Base.connection.execute("Truncate table summary_conversions ")
        range += 20000
      end
    end

    def inverted_order(database)
      range = 20000
      while range < 100001 do
        ActiveRecord::Base.connection.execute("Truncate table summary_conversions ")
        @client.run("insert into summary_conversions select cast(approx_set(number) as varbinary) as conversion_hll_sketch from #{database}  where number < #{range} group by number order by number desc")
        columns, rows = @client.run("select cardinality(merge(cast(hll as HyperLogLog))) as daily_conversions from summary_conversions")
        #Return cardinality
        puts "Cardinality for #{range}: #{rows}"
        range += 20000
      end
    end

    def random_shuffling(database)
      range = 20000
      while range < 100001 do
        ActiveRecord::Base.connection.execute("Truncate table summary_conversions ")
        @client.run("insert into summary_conversions select cast(approx_set(number) as varbinary) as conversion_hll_sketch from #{database}  where number < #{range} group by number order by RAND()")
        columns, rows = @client.run("select cardinality(merge(cast(hll as HyperLogLog))) as daily_conversions from summary_conversions")
        #Return cardinality
        puts "Cardinality for #{range}: #{rows}"
        range += 20000
      end
    end
  end
end
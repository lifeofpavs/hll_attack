require 'presto-client'
module Utils
  class PrestoDb 
    def initialize
      # create a client object:
      @client = Presto::Client.new(
        server: "localhost:8080",   # required option
        catalog: "mysql",
        schema: "test",
        user: "root",
        time_zone: "US/Pacific",
        language: "English"
      )
    end

    def get_cardinality
      # run a query and get results as an array of arrays:
      #ActiveRecord::Base.connection.execute("Truncate table summary_test")
      #Building cardinality
      
      @client.run("insert into summary_test select cast(approx_set(conversion_id) as varbinary) as conversion_hll_sketch, conversion_date from conversions group by conversion_date")
      #Get cardinality
      columns, rows = @client.run("select cardinality(merge(cast(hll as HyperLogLog))) as daily_conversions from summary_test")
      #Return cardinality
      puts "Cardinality: #{rows}"
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
  end
end
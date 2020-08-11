class CreateExecutions < ActiveRecord::Migration[5.2]
  def change
    create_table :executions do |t|
      t.string :time
      t.integer :vector_size

      t.timestamps
    end
  end
end

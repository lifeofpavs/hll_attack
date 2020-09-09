class CreateAttackVectorFiltereds < ActiveRecord::Migration[5.2]
  def change
    create_table :attack_vector_filtereds do |t|
      t.integer :number

      t.timestamps
    end
  end
end

class CreateAttackVectorFase2s < ActiveRecord::Migration[5.2]
  def change
    create_table :attack_vector_fase2s do |t|
      t.integer :number

      t.timestamps
    end
  end
end

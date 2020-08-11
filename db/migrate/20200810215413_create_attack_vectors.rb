class CreateAttackVectors < ActiveRecord::Migration[5.2]
  def change
    create_table :attack_vectors do |t|
      t.integer :number

      t.timestamps
    end
  end
end

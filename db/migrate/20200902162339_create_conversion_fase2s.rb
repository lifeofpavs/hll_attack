class CreateConversionFase2s < ActiveRecord::Migration[5.2]
  def change
    create_table :conversion_fase2s do |t|
      t.integer :conversion_id
      t.date :conversion_date
      t.integer :user_id

      t.timestamps
    end
  end
end

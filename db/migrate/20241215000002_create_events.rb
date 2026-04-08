class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :events do |t|
      t.string :title, null: false
      t.text :description
      t.string :venue
      t.string :city
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :status, default: "draft"
      t.bigint :user_id
      t.string :category
      t.integer :max_capacity
      t.timestamps
    end
  end
end

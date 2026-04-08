class CreateTicketTiers < ActiveRecord::Migration[7.1]
  def change
    create_table :ticket_tiers do |t|
      t.string :name, null: false
      t.decimal :price, precision: 10, scale: 2
      t.integer :quantity, default: 0
      t.integer :sold_count, default: 0
      t.bigint :event_id
      t.datetime :sales_start
      t.datetime :sales_end
      t.timestamps
    end
  end
end

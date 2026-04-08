class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.bigint :user_id
      t.bigint :event_id
      t.string :status, default: "pending"
      t.decimal :total_amount, precision: 10, scale: 2
      t.string :confirmation_number
      t.timestamps
    end
  end
end

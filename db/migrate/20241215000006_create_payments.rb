class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.bigint :order_id
      t.decimal :amount, precision: 10, scale: 2
      t.string :status, default: "pending"
      t.string :provider, default: "stripe"
      t.string :provider_reference
      t.text :failure_reason
      t.timestamps
    end
  end
end

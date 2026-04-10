class CreateBookmarks < ActiveRecord::Migration[7.1]
  def change
    create_table :bookmarks do |t|
      t.references :user,  null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true

      t.timestamps
    end

    # DB-level uniqueness: one bookmark per user per event
    add_index :bookmarks, [:user_id, :event_id], unique: true
  end
end

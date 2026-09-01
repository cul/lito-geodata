# frozen_string_literal: true

class AddUidToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :uid, :string
    add_index :users, :uid, unique: true
  end
end

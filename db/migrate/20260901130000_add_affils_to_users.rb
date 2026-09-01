# frozen_string_literal: true

class AddAffilsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :affils, :text
  end
end


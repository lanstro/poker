class AddTableBalanceToUsers < ActiveRecord::Migration
  def change
    add_column :users, :table_balance, :text
  end
end

class AddOnboardingStepToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :onboarding_step, :integer, default: 0, null: false
  end
end

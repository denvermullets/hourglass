class Servers::CreateService < Service
  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def call
    ActiveRecord::Base.transaction do
      server = Server.create!(@params.merge(owner: @user))
      server.memberships.create!(user: @user, role: :owner)
      server
    end
  end
end

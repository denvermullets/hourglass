class Servers::CreateService < Service
  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def call
    ActiveRecord::Base.transaction do
      server = Server.create!(@params.merge(owner: @user))
      server.memberships.create!(user: @user, role: :owner)

      category = server.categories.create!(name: 'general', position: 0)
      category.channels.create!(name: 'general', server: server, channel_type: :text, position: 0)

      server
    end
  end
end

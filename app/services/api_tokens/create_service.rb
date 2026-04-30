module ApiTokens
  class CreateService < Service
    def initialize(user:, params:)
      @user = user
      @params = params
    end

    def call
      ApiToken.generate_for(@user, name: @params[:name].to_s.strip)
    end
  end
end

module ApiTokens
  class CreateService < Service
    def initialize(user:, params:)
      @user = user
      @params = params
    end

    def call
      ApiToken.generate_for(@user, name: @params[:name].to_s.strip, server: server)
    end

    private

    # A submitted id that doesn't resolve must fail loudly rather than fall back
    # to an unbound (all-servers) token. Membership is validated on ApiToken.
    def server
      server_id = @params[:server_id].presence
      return nil unless server_id

      Server.find_by(id: server_id) || raise_unknown_server
    end

    def raise_unknown_server
      token = ApiToken.new(user: @user, name: @params[:name])
      token.errors.add(:server, 'must be a server you belong to')
      raise ActiveRecord::RecordInvalid, token
    end
  end
end

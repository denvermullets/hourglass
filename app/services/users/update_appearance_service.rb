class Users::UpdateAppearanceService < Service
  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def call
    current = @user.settings || {}
    appearance = current.fetch('appearance', {})

    appearance['theme'] = @params[:theme] if @params.key?(:theme)
    appearance['timestamp_format'] = @params[:timestamp_format] if @params.key?(:timestamp_format)

    @user.update!(settings: current.merge('appearance' => appearance))
    @user
  end
end

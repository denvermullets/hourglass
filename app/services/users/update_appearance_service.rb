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
    appearance['sidebar_position'] = @params[:sidebar_position] if @params.key?(:sidebar_position)
    appearance['text_size'] = @params[:text_size] if @params.key?(:text_size)
    appearance['text_size_mobile'] = @params[:text_size_mobile] if @params.key?(:text_size_mobile)

    @user.update!(settings: current.merge('appearance' => appearance))
    @user
  end
end

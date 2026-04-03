class Users::UpdateAppearanceService < Service
  def initialize(user:, params:)
    @user = user
    @params = params
  end

  APPEARANCE_KEYS = %w[theme timestamp_format timezone sidebar_position text_size text_size_mobile].freeze

  def call
    current = @user.settings || {}
    appearance = current.fetch('appearance', {})

    APPEARANCE_KEYS.each do |key|
      appearance[key] = @params[key.to_sym] if @params.key?(key.to_sym)
    end

    @user.update!(settings: current.merge('appearance' => appearance))
    @user
  end
end

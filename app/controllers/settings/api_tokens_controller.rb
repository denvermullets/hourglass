class Settings::ApiTokensController < ApplicationController
  layout 'app'

  def index
    @tokens = current_user_tokens
    render_tab
  end

  def create
    @token, @plaintext = ApiTokens::CreateService.call(user: Current.user, params: token_params)
    @tokens = current_user_tokens
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to settings_api_tokens_path }
    end
  rescue ActiveRecord::RecordInvalid => e
    @error = e.record.errors.full_messages.to_sentence
    @tokens = current_user_tokens
    render_tab(status: :unprocessable_entity)
  end

  def destroy
    token = Current.user.api_tokens.find(params[:id])
    token.revoke!
    @tokens = current_user_tokens
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to settings_api_tokens_path }
    end
  end

  private

  def current_user_tokens
    Current.user.api_tokens.active.order(created_at: :desc)
  end

  def render_tab(status: :ok)
    locals = { tokens: @tokens, plaintext: @plaintext, new_token: @token, error: @error }
    if turbo_frame_request?
      render partial: 'settings/tabs_and_panel',
             locals: { tab: 'api_tokens', panel_partial: 'settings/api_tokens/tokens_content', panel_locals: locals },
             status: status
    else
      @tab = 'api_tokens'
      @panel_partial = 'settings/api_tokens/tokens_content'
      @panel_locals = locals
      render 'settings/show', status: status
    end
  end

  def token_params
    params.require(:api_token).permit(:name)
  end
end

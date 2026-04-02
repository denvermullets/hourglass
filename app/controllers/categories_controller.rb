class CategoriesController < ApplicationController
  include Authorization

  layout 'app'

  before_action :set_server
  before_action :set_category, only: %i[update destroy reorder archive unarchive]
  before_action :require_membership!
  before_action :require_moderator!

  def create
    @category = Categories::CreateService.call(server: @server, params: category_params)
    redirect_to server_path(@server)
  rescue ActiveRecord::RecordInvalid => e
    @category = e.record
    redirect_to server_path(@server), alert: 'Could not create category.'
  end

  def update
    Categories::UpdateService.call(category: @category, params: category_params)
    redirect_to server_path(@server)
  rescue ActiveRecord::RecordInvalid
    redirect_to server_path(@server), alert: 'Could not update category.'
  end

  def destroy
    @category.destroy!
    redirect_to server_path(@server)
  end

  def reorder
    Categories::ReorderService.call(category: @category, direction: params[:direction].to_sym)
    redirect_to settings_channels_server_path(@server)
  end

  def archive
    Categories::ArchiveService.call(category: @category)
    redirect_to settings_channels_server_path(@server)
  end

  def unarchive
    Categories::UnarchiveService.call(category: @category)
    redirect_to settings_channels_server_path(@server)
  end

  private

  def set_server
    @server = Server.find(params[:server_id])
  end

  def set_category
    @category = @server.all_categories.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name)
  end
end

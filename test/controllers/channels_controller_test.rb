require 'test_helper'

class ChannelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server = servers(:one)
    @channel = channels(:general)
    @server.channels.create!(name: 'releases', category: categories(:general), channel_type: :text)
  end

  test 'show renders the move action and picker dialog for an admin' do
    sign_in_as(users(:one)) # owner of server one
    get server_channel_path(@server, @channel)

    assert_response :ok
    assert_match 'message-mover#open', response.body
    assert_match 'data-message-mover-target="dialog"', response.body
    assert_match 'releases', response.body
  end

  test 'show hides the move action and dialog from a regular member' do
    sign_in_as(users(:two)) # plain member of server one
    get server_channel_path(@server, @channel)

    assert_response :ok
    assert_no_match 'message-mover#open', response.body
    assert_no_match 'data-message-mover-target="dialog"', response.body
  end

  test 'server settings channel list offers a rename affordance per channel' do
    sign_in_as(users(:one))
    get settings_channels_server_path(@server)

    assert_response :ok
    assert_select "turbo-frame#name_channel_#{@channel.id} a[href=?]",
                  edit_name_server_channel_path(@server, @channel)
  end

  test 'channel settings page offers a rename form' do
    sign_in_as(users(:one))
    get server_channel_settings_path(@server, @channel)

    assert_response :ok
    assert_select "form[action=?] input[name='channel[name]'][value=?]",
                  rename_server_channel_path(@server, @channel), @channel.name
    assert_select "form[action=?] input[name='return_to'][value='channel_settings']",
                  rename_server_channel_path(@server, @channel)
  end

  test 'edit_name renders the inline rename frame for a moderator+' do
    sign_in_as(users(:one))
    get edit_name_server_channel_path(@server, @channel)

    assert_response :ok
    assert_select "turbo-frame#name_channel_#{@channel.id} form[action=?]",
                  rename_server_channel_path(@server, @channel)
  end

  test 'edit_name is refused for a regular member' do
    sign_in_as(users(:two))
    get edit_name_server_channel_path(@server, @channel)

    assert_redirected_to server_path(@server)
  end

  test 'rename updates the name and returns to the server settings channel list' do
    sign_in_as(users(:one))
    patch rename_server_channel_path(@server, @channel), params: { channel: { name: 'Team Updates' } }

    assert_redirected_to settings_channels_server_path(@server)
    assert_equal 'team-updates', @channel.reload.name
  end

  test 'rename returns to the channel settings page when asked' do
    sign_in_as(users(:one))
    patch rename_server_channel_path(@server, @channel),
          params: { channel: { name: 'planning' }, return_to: 'channel_settings' }

    assert_redirected_to server_channel_settings_path(@server, @channel)
    assert_equal 'planning', @channel.reload.name
  end

  test 'rename re-renders the frame with the error when the name is taken' do
    sign_in_as(users(:one))
    patch rename_server_channel_path(@server, @channel), params: { channel: { name: 'releases' } }

    assert_response :unprocessable_entity
    assert_select "turbo-frame#name_channel_#{@channel.id}"
    assert_match 'has already been taken', response.body
    assert_equal 'general', @channel.reload.name
  end

  test 'rename is refused for a regular member' do
    sign_in_as(users(:two))
    patch rename_server_channel_path(@server, @channel), params: { channel: { name: 'nope' } }

    assert_redirected_to server_path(@server)
    assert_equal 'general', @channel.reload.name
  end
end

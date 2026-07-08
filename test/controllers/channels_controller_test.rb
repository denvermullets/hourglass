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
end

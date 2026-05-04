require 'test_helper'

class MentionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other = users(:two)
    @server = servers(:one)
    @channel = channels(:general)
    sign_in_as(@user)
  end

  test 'returns local users matching the query' do
    get mentions_search_path, params: { q: 'usertw', channel_id: @channel.id }
    assert_response :success
    body = JSON.parse(response.body)
    usernames = body.map { |row| row['username'] }
    assert_includes usernames, 'usertwo'
    assert_not_includes usernames, 'userone'
    assert(body.all? { |row| row['external'] == false })
  end

  test 'excludes mtasks rows for unlinked channels' do
    get mentions_search_path, params: { q: 'one', channel_id: @channel.id }
    assert_response :success
    body = JSON.parse(response.body)
    assert(body.none? { |row| row['external'] == true })
  end

  test 'merges external mtasks rows when channel is linked' do
    integration = server_integrations(:jait_one)
    MtasksLink.create!(
      link_type: MtasksLink::PROJECT_CHANNEL,
      server_integration: integration, channel: @channel,
      mtasks_team_id: 21, mtasks_project_id: 7,
      created_by_user: @user
    )
    external = User.create!(username: 'ext', email_address: 'ext@example.com', password: 'password')
    MtasksUserMap.create!(hourglass_user: external, mtasks_user_id: 9001, email: 'externie@example.com')

    get mentions_search_path, params: { q: 'externie', channel_id: @channel.id }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.size
    row = body.first
    assert_equal 'externie@example.com', row['username']
    assert_equal true, row['external']
    assert_equal 9001, row['mtasks_user_id']
  end

  test 'dedupes external rows whose hourglass user already matched locally' do
    integration = server_integrations(:jait_one)
    MtasksLink.create!(
      link_type: MtasksLink::PROJECT_CHANNEL,
      server_integration: integration, channel: @channel,
      mtasks_team_id: 21, mtasks_project_id: 7,
      created_by_user: @user
    )
    @other.update!(username: 'twotwo')
    MtasksUserMap.find_by(hourglass_user: @other).update!(email: 'twotwo@example.com')

    get mentions_search_path, params: { q: 'twotwo', channel_id: @channel.id }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.size
    assert_equal false, body.first['external']
    assert_equal 'twotwo', body.first['username']
  end

  test 'returns empty when channel does not exist' do
    get mentions_search_path, params: { q: 'a', channel_id: 99_999 }
    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test 'returns empty when user is not a member of the server' do
    other_user = User.create!(username: 'outsider', email_address: 'out@example.com', password: 'password')
    sign_in_as(other_user)
    get mentions_search_path, params: { q: 'usertw', channel_id: @channel.id }
    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test 'response does not leak hourglass_user_id' do
    get mentions_search_path, params: { q: 'usertw', channel_id: @channel.id }
    body = JSON.parse(response.body)
    assert(body.none? { |row| row.key?('hourglass_user_id') })
  end
end

require 'test_helper'

class ApiTokenTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'generate_for returns persisted token and raw value' do
    token, raw = ApiToken.generate_for(@user, name: 'test')

    assert token.persisted?
    assert raw.is_a?(String)
    assert raw.length >= 32
    assert_equal @user, token.user
    assert_equal 'test', token.name
    assert_equal %w[read write], token.scopes
    assert_nil token.revoked_at
  end

  test 'generate_for stores sha256 digest, not raw value' do
    _token, raw = ApiToken.generate_for(@user, name: 'digest-check')
    stored = ApiToken.last

    assert_equal Digest::SHA256.hexdigest(raw), stored.token_digest
    refute_includes stored.attributes.values.compact.map(&:to_s), raw
  end

  test 'authenticate finds active token by raw' do
    _token, raw = ApiToken.generate_for(@user, name: 'auth')

    found = ApiToken.authenticate(raw)
    assert_equal @user, found.user
  end

  test 'authenticate returns nil for unknown raw' do
    assert_nil ApiToken.authenticate('not-a-real-token')
  end

  test 'authenticate returns nil for blank raw' do
    assert_nil ApiToken.authenticate('')
    assert_nil ApiToken.authenticate(nil)
  end

  test 'authenticate returns nil for revoked tokens' do
    token, raw = ApiToken.generate_for(@user, name: 'soon revoked')
    token.revoke!

    assert_nil ApiToken.authenticate(raw)
  end

  test 'revoke! sets revoked_at and marks revoked?' do
    token, _raw = ApiToken.generate_for(@user, name: 'to revoke')

    assert_not token.revoked?
    token.revoke!
    assert token.revoked?
    assert_not_nil token.revoked_at
  end

  test 'has_scope? checks scope membership' do
    token, _raw = ApiToken.generate_for(@user, name: 'scoped')

    assert token.has_scope?(:read)
    assert token.has_scope?('write')
    assert_not token.has_scope?(:admin)
  end

  test 'invalid scope rejected' do
    token = ApiToken.new(user: @user, name: 'bad', token_digest: 'x', scopes: %w[admin])
    assert_not token.valid?
    assert_includes token.errors[:scopes].first, 'subset'
  end

  test 'requires name' do
    token = ApiToken.new(user: @user, name: '', token_digest: 'x')
    assert_not token.valid?
    assert_includes token.errors[:name], "can't be blank"
  end

  test 'token_digest unique' do
    ApiToken.create!(user: @user, name: 'a', token_digest: 'duplicate')
    dup = ApiToken.new(user: users(:two), name: 'b', token_digest: 'duplicate')
    assert_not dup.valid?
  end

  test 'touch_used! updates last_used_at' do
    token, _raw = ApiToken.generate_for(@user, name: 'used')
    assert_nil token.last_used_at

    token.touch_used!
    assert_not_nil token.reload.last_used_at
  end

  test 'active scope excludes revoked' do
    fixture_active = api_tokens(:active_one)
    fixture_revoked = api_tokens(:revoked_one)

    active_ids = ApiToken.active.pluck(:id)
    assert_includes active_ids, fixture_active.id
    assert_not_includes active_ids, fixture_revoked.id
  end
end

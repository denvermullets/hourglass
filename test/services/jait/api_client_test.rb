require 'test_helper'

module Jait
  class ApiClientTest < ActiveSupport::TestCase
    setup do
      @integration = server_integrations(:jait_one)
      @client = Jait::ApiClient.new(@integration)
    end

    def stub_get(value)
      @client.define_singleton_method(:get) { |_path| value.is_a?(Proc) ? value.call : value }
    end

    test 'fetch_projects unwraps {"projects": [...]} envelope' do
      stub_get({ 'projects' => [{ 'id' => 1, 'name' => 'Alpha' }] })
      result = @client.fetch_projects(21)
      assert_equal 1, result.size
      assert_equal 'Alpha', result.first['name']
    end

    test 'fetch_projects returns the array as-is when no envelope' do
      stub_get([{ 'id' => 1, 'name' => 'Alpha' }])
      result = @client.fetch_projects(21)
      assert_equal 'Alpha', result.first['name']
    end

    test 'fetch_projects propagates Jait::ApiClient::NotFound' do
      stub_get(-> { raise Jait::ApiClient::NotFound, 'gone' })
      assert_raises(Jait::ApiClient::NotFound) { @client.fetch_projects(21) }
    end
  end
end

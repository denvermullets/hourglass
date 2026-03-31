require 'test_helper'

module Servers
  class UpdateSettingsServiceTest < ActiveSupport::TestCase
    test 'updates server name' do
      server = servers(:one)
      Servers::UpdateSettingsService.call(server: server, params: { name: 'Updated Name' })
      assert_equal 'Updated Name', server.reload.name
    end

    test 'updates server description' do
      server = servers(:one)
      Servers::UpdateSettingsService.call(server: server, params: { description: 'New desc' })
      assert_equal 'New desc', server.reload.description
    end

    test 'raises on invalid params' do
      assert_raises(ActiveRecord::RecordInvalid) do
        Servers::UpdateSettingsService.call(server: servers(:one), params: { name: '' })
      end
    end
  end
end

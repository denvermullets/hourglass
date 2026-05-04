require 'test_helper'

module Messages
  class SlashCommandParserTest < ActiveSupport::TestCase
    test 'detects /issue with title' do
      result = Messages::SlashCommandParser.detect('<p>/issue Add billing fields</p>')
      assert_not_nil result
      assert_equal 'issue', result[:command].name
      assert_equal 'Add billing fields', result[:args]
    end

    test 'detects /issue with no title (empty args)' do
      result = Messages::SlashCommandParser.detect('<p>/issue</p>')
      assert_not_nil result
      assert_equal 'issue', result[:command].name
      assert_equal '', result[:args]
    end

    test 'returns nil for plain text' do
      assert_nil Messages::SlashCommandParser.detect('<p>just a regular message</p>')
    end

    test 'returns nil for unknown command' do
      assert_nil Messages::SlashCommandParser.detect('<p>/unknown thing</p>')
    end

    test 'returns nil when slash is not at the start' do
      assert_nil Messages::SlashCommandParser.detect('<p>hello /issue Foo</p>')
    end

    test 'tolerates leading and trailing whitespace' do
      result = Messages::SlashCommandParser.detect('<p>  /issue Foo  </p>')
      assert_not_nil result
      assert_equal 'Foo', result[:args]
    end

    test 'handler is resolved lazily via constantize' do
      cmd = Messages::SlashCommandParser::COMMANDS['issue']
      assert_equal Messages::SlashCommands::IssueHandler, cmd.handler
    end

    test 'detects /link with an identifier' do
      result = Messages::SlashCommandParser.detect('<p>/link HOUR-91</p>')
      assert_not_nil result
      assert_equal 'link', result[:command].name
      assert_equal 'HOUR-91', result[:args]
    end

    test 'detects /status with a keyword' do
      result = Messages::SlashCommandParser.detect('<p>/status done</p>')
      assert_not_nil result
      assert_equal 'status', result[:command].name
      assert_equal 'done', result[:args]
    end

    test 'detects /unlink with empty args' do
      result = Messages::SlashCommandParser.detect('<p>/unlink</p>')
      assert_not_nil result
      assert_equal 'unlink', result[:command].name
      assert_equal '', result[:args]
    end

    test 'link/status/unlink handlers resolve via constantize' do
      assert_equal Messages::SlashCommands::LinkHandler,
                   Messages::SlashCommandParser::COMMANDS['link'].handler
      assert_equal Messages::SlashCommands::StatusHandler,
                   Messages::SlashCommandParser::COMMANDS['status'].handler
      assert_equal Messages::SlashCommands::UnlinkHandler,
                   Messages::SlashCommandParser::COMMANDS['unlink'].handler
    end
  end
end

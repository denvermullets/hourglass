class Messages::SlashCommandParser
  Command = Struct.new(:name, :handler_class_name, :description, :usage, keyword_init: true) do
    def handler
      handler_class_name.constantize
    end
  end

  COMMANDS = {} # rubocop:disable Style/MutableConstant -- populated by register

  def self.register(name, handler_class_name:, description:, usage:)
    COMMANDS[name.to_s] = Command.new(
      name: name.to_s, handler_class_name: handler_class_name,
      description: description, usage: usage
    )
  end

  def self.commands
    COMMANDS.values
  end

  def self.detect(html_body)
    text = plain_text(html_body)
    return nil unless text.start_with?('/')

    match = text.match(%r{\A/(\w+)(?:\s+(.*))?\z}m)
    return nil unless match

    command = COMMANDS[match[1]]
    return nil unless command

    { command: command, args: match[2].to_s.strip }
  end

  def self.plain_text(html)
    Nokogiri::HTML.fragment(html.to_s).text.strip
  end

  register('issue',
           handler_class_name: 'Messages::SlashCommands::IssueHandler',
           description: 'spawn a new issue from this thread',
           usage: '/issue [title]')
end

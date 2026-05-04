class Mentions::SearchService < Service
  LIMIT = 10

  def initialize(channel:, query:, current_user:)
    @channel = channel
    @query = query.to_s.strip
    @current_user = current_user
  end

  def call
    locals = local_results
    return locals unless @channel.mtasks_project_link.present?

    excluded_user_ids = locals.map { |row| row[:hourglass_user_id] }.compact
    externals = external_results(excluded_user_ids)
    (locals + externals).first(LIMIT)
  end

  private

  def local_results
    @channel.server.users
            .where('username ILIKE ?', "#{@query}%")
            .where.not(id: @current_user.id)
            .limit(LIMIT)
            .map do |u|
      {
        username: u.username,
        display_name: u.display_name,
        external: false,
        mtasks_user_id: nil,
        hourglass_user_id: u.id
      }
    end
  end

  def external_results(excluded_user_ids)
    scope = MtasksUserMap.where('email ILIKE ?', "#{@query}%")
    scope = scope.where.not(hourglass_user_id: excluded_user_ids) if excluded_user_ids.any?
    scope.limit(LIMIT).map do |row|
      {
        username: row.email,
        display_name: row.email,
        external: true,
        mtasks_user_id: row.mtasks_user_id,
        hourglass_user_id: row.hourglass_user_id
      }
    end
  end
end

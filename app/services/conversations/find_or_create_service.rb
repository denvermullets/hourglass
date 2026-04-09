class Conversations::FindOrCreateService < Service
  def initialize(creator:, user_ids:, name: nil, is_group: false)
    @creator = creator
    @user_ids = user_ids
    @name = name
    @is_group = is_group
  end

  def call
    all_user_ids = ([@creator.id] + @user_ids).uniq

    if !@is_group && all_user_ids.size == 2
      existing = find_existing_one_on_one(all_user_ids)
      return existing if existing
    end

    conversation = Conversation.create!(
      is_group: @is_group || all_user_ids.size > 2,
      name: @name
    )

    all_user_ids.each do |user_id|
      conversation.conversation_memberships.create!(user_id: user_id)
    end

    conversation
  end

  private

  def find_existing_one_on_one(user_ids)
    Conversation
      .where(is_group: false)
      .joins(:conversation_memberships)
      .where(conversation_memberships: { user_id: user_ids })
      .group('conversations.id')
      .having('COUNT(conversation_memberships.id) = 2')
      .first
  end
end

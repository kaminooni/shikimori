class MessagesQuery < SimpleQueryBase
  pattr_initialize :user, :messages_type

  NEWS_KINDS = [
    MessageType::Anons,
    MessageType::Ongoing,
    MessageType::Episode,
    MessageType::Released,
    MessageType::SiteNews,
    MessageType::ContestFinished,
    MessageType::ClubBroadcast
  ]
  NOTIFICATION_KINDS = [
    MessageType::FriendRequest,
    MessageType::ClubRequest,
    MessageType::Notification,
    MessageType::ProfileCommented,
    MessageType::QuotedByUser,
    MessageType::SubscriptionCommented,
    MessageType::NicknameChanged,
    MessageType::Banned,
    MessageType::Warned,
    MessageType::VersionAccepted,
    MessageType::VersionRejected,
  ]

  def query
    Message
      .where(where_by_type)
      .where(where_by_sender)
      .where.not(from_id: ignores_ids, to_id: ignores_ids)
      .includes(:linked, :from, :to)
      .order(*order_by_type)
  end

  def where_by_type
    case @messages_type
      when :inbox then { kind: [MessageType::Private] }
      when :private then { kind: [MessageType::Private], read: false }
      when :sent then { kind: [MessageType::Private] }
      when :news then { kind: NEWS_KINDS }
      when :notifications then { kind: NOTIFICATION_KINDS }
      else raise ArgumentError, "unknown type: #{@messages_type}"
    end
  end

private

  def ignores_ids
    @ignores_ids ||= @user.ignores.map(&:target_id) << 0
  end

  def order_by_type
    case @messages_type
      when :private then 'read, (case when read=true then -id else id end)'
      else [:read, id: :desc]
    end
  end

  def where_by_sender
    if @messages_type == :sent
      { from_id: @user.id }
    else
      { to_id: @user.id, is_deleted_by_to: false }
    end
  end
end

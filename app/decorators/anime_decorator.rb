class AnimeDecorator < AniMangaDecorator
  instance_cache :files, :next_episode_at

  # новости
  def news_topic_views
    object
      .news_topics
      .where(locale: h.locale_from_host)
      .includes(:forum)
      .limit(NEWS_PER_PAGE)
      .order(:created_at)
      .map { |topic| Topics::TopicViewFactory.new(false, false).build topic }
      .map { |topic_view| format_menu_topic topic_view, :created_at }
  end

  # скриншоты
  def screenshots limit = nil
    return [] if Copyright::SCREENSHOTS.include?(id)
    return [] unless h.ignore_copyright?
    return [] unless display_sensitive?
    # return [] if forbidden?

    @screenshots ||= {}
    @screenshots[limit] ||=
      if object.respond_to? :screenshots
        object.screenshots.limit limit
      else
        []
      end
  end

  # видео
  def videos limit = nil
    return [] if Copyright::VIDEOS.include?(id)
    return [] unless h.ignore_copyright?
    # return [] if forbidden?

    @videos ||= {}
    @videos[limit] ||=
      if object.respond_to? :videos
        object.videos.limit limit
      else
        []
      end
  end

  # презентер файлов
  def files
    AniMangaDecorator::Files.new object
  end

  # дата выхода следующего эпизода
  def next_episode_at with_broadcast = true
    if ongoing? || anons?
      calendars = anime_calendars
        .where(episode: [episodes_aired + 1, episodes_aired + 2])
        .to_a

      date =
        if calendars[0].present? && calendars[0].start_at > Time.zone.now
          calendars[0].start_at

        elsif calendars[1].present?
          calendars[1].start_at
        end

      date || object.next_episode_at || (next_broadcast_at if with_broadcast)
    end
  end

  # для анонса перебиваем дату анонса на дату с анимекалендаря,
  # если таковая имеется
  def aired_on
    anons? && next_episode_at(false) ? next_episode_at(false) : object.aired_on
  end

  # тип элемента для schema.org
  def itemtype
    'http://schema.org/Movie'
  end

  def licensed?
    if h.current_user&.video_moderator? ||
        h.current_user&.trusted_video_uploader?
      return false
    end

    # Copyright::DAISUKI_COPYRIGHTED.include?(id) ||
    Copyright::IVI_RU_COPYRIGHTED.include?(id) ||
      Copyright::OTHER_COPYRIGHTED.include?(id) || (
        Copyright::WAKANIM_COPYRIGHTED.include?(id) &&
        !GeoipAccess.instance.wakanim_allowed?(h.remote_addr)
      )
  end

private

  def next_broadcast_at
    if broadcast_at && broadcast_at > 1.week.ago
      broadcast_at < 1.hour.ago ? broadcast_at + 1.week : broadcast_at
    end
  end
end

# frozen_string_literal: true

# TODO: refactoring & add specs
class TorrentsParser
  PROXY_LOG = ENV['RAILS_ENV'] == 'development' ? true : false
  USE_PROXY = false#ENV['RAILS_ENV'] == 'development' ? false : true

  IGNORED_TORRENTS = Set.new [
    'Chuunibyou demo Koi ga Shitai! Lite - 04 (640x360 x264 AAC).mp4',
    '[WZF]Ore_no_Imouto_ga_Konna_ni_Kawaii_Wake_ga_Nai_-_Capitulo_13-15[BDRip][X264-AAC][1280x720][Sub_Esp]',
    'Owari Subs] Mahouka Koukou no Rettousei ~ Esplorando Mahouka 03 [Webrip][207F8116].mkv',
    '[iPUNISHER] Mahouka Koukou No Rettousei - Yoku Wakaru Mahouka - 03 [720p][AAC].mkv',
    '[모에-Raws] Kuzu no Honkai #04 (CX 1280x720 x264 AAC).mp4'
  ]
  IGNORED_PHRASES = [
    %w[Flying Witch Petit],
    %w[Tompel Fansub]
  ]

  IGNORED_ANIME_IDS = [
    13185, 19207, 5042, 17249, 11457, 21729, 22757, 32670, 31670, 31592, 10937,
    34454, 31499
  ]

  ANIME_WITH_NAME_MATCH_ONLY = [10049, 10033, 6336, 11319]
  ANIME_WITH_EXACT_NAME_MATCH = [
    10161, 10490, 10379, 6336, 11319, 14645, 15085, 14967, 15611, 17705, 15699,
    16241, 16049, 34984
  ]
  ANIME_WITH_ALL_SUB_GROUPS = [9539, 12979, 13163, 6702, 15417]

  END_OF_NAME = /[\w\)!~?\.+-‒]/
  EPISODE_FOR_HISTORY_REGEXES = %r(
    #{END_OF_NAME} # завершающий кусочек названия
    (?: _- )?
    _
    \#?
    (?:Vol\.)?
    (?:CH-)?
    (\d+) # номер эпизода
    (?: _-_Part_\d )?
    (?: v[0-3] )? # v0 v1 v2 - версия релиза
    (?: _ \( \d{1,2} \) )? # в скобках дополнительная нумерация эпизода
    [_-]*
    (?: _rev\d )?
    (?: _RAW | _END )?
    (?: # различные варианты концовки
      [_-]+
      (?:
          \[(1080|720|480)p\] _? \[ .*
        |
          (?: \(|\[ ) [\w _-]{2,8} (?: 1280|1920 )x .*
        |
          \[\w{8}\]
        |
          (?: \(|\[ )
            (?: (?: [\w-]{2,4}_ )? \d{3} | [A-Z] )
          .*
      )
    )?
    \. (?: mp4 | mp3 | mkv | avi )
    $
  )mix
  EPISODES_FOR_HISTORY_REGEXES = [
    /Vol\.(\d+)-(\d+)_(?:\[|\()(?:BD|DVD)/i,
    /#{END_OF_NAME}_(\d+)-(\d+)(?:_RAW|_END)?_?(?:\(|\[)(?:\d{3}|[A-Z])/i,
    /#{END_OF_NAME}_(\d+)-(\d+)_\[(?:DVD|BD|ENG|JP|JAP)/i,
    /#{END_OF_NAME}_\((\d+)-(\d+)\)_\[(1080|720|480)p\]/i
  ]
  EPISODES_WITH_COMMA_FOR_HISTORY_REGEXES = [
    /#{END_OF_NAME}_(\d+)-(\d+),_?(\d+)_raw_720/i
  ]

  def self.extract_episodes_num episode_name
    return [] if IGNORED_TORRENTS.include? episode_name
    return [] if ignored_phrases? episode_name

    num = parse_episodes_num(episode_name).select {|v| v < 1000 }

    if episode_name =~ /cardfight!![ _]vanguard/i && episode_name =~ /link[ _]joker/i
      num.map { |v| v - 104 }
    elsif episode_name =~ /THE iDOLM@STER Cinderella Girls/i
      num.map { |v| v - 13 }
    elsif episode_name =~ /Yu-Gi-Oh![ _]Zexal[ _]II/i
      num.map { |v| v - 73 }
    elsif episode_name =~ /stardust[ _]crusaders/i
      num.map { |v| v > 24 ? v - 24 : v }
    elsif episode_name =~ /kuroko[ _]no[ _](basuke|basket)/i
      num.map { |v| v > 25 ? v - 25 : v }
    elsif episode_name =~ /fairy[ _]?tail/i
      num.map { |v| v > 175 ? v - 175 : v }
    elsif episode_name =~ /kyousou[ _]?giga/i
      num.map { |v| v + 1 }
    elsif episode_name =~ /my[ _]hero[ _]academia|boku[ _]no[ _]hero[ _]academia/i
      num.map { |v| v - 13 }
    else
      num
    end.select { |v| v > 0 }
  end

  def self.parse_episodes_num episode_name
    fixed_name = episode_name.gsub ' ', '_'

    Array(EPISODE_FOR_HISTORY_REGEXES).each do |regex|
      return [$1.to_i] if fixed_name.match(regex)
    end
    EPISODES_FOR_HISTORY_REGEXES.each do |regex|
      return (($1.to_i)..($2.to_i)).to_a if fixed_name.match(regex)
    end
    EPISODES_WITH_COMMA_FOR_HISTORY_REGEXES.each do |regex|
      return (($1.to_i)..($2.to_i)).to_a << $3.to_i if fixed_name.match(regex)
    end
    []
  end

  def self.grab_ongoings test=false, anime_id=nil
    parse_feed get_rss, anime_id
  end

  def self.grab_page url, anime_id=nil
    parse_feed get_page(url), anime_id
  end

  def self.get_rss
    content = get(rss_url)

    doc = Nokogiri::XML(content)
    feed = doc.xpath('//channel//item').map do |v|
      category = v.xpath('category')[0]
      next if category && category.inner_html =~ /^(?:English-scanlated Books|Raw Books)$/
      {
        title: v.xpath('title')[0].inner_html,
        link: v.xpath('link')[0].inner_html.gsub('&amp;', '&'),
        guid: v.xpath('guid')[0].inner_html.gsub('&amp;', '&'),
        pubDate: DateTime.parse(v.xpath('pubDate')[0].inner_html),
      }
    end.compact

    filter_bad_formats(feed)
  end

  def self.parse_feed feed, anime_id
    print "fetched %d torrens\n" % feed.size
    return 0 if feed.empty?

    animes = if anime_id != nil
      [Anime.find(anime_id)]
    else
      get_ongoings
    end

    animes.sum do |anime|
      matches = feed.select do |v|
        unless ANIME_WITH_ALL_SUB_GROUPS.include?(anime.id) # некоторые аниме только эти негодяи сабят
          next if v[:title].include? '[KRT]' # эти негодяи совсем криво торренты именуют
          next if v[:title].include? '[Arabic]' # это вообще какие-то неадекваты
        end

        TorrentsMatcher.new(anime).matches_for(
          v[:title],
          only_name: ANIME_WITH_NAME_MATCH_ONLY.include?(anime.id),
          exact_name: ANIME_WITH_EXACT_NAME_MATCH.include?(anime.id)
        )
      end

      matches.any? ? add_episodes(anime, matches) : 0
    end
  end

  def self.get_ongoings
    ongoings = Anime.where(status: :ongoing).to_a

    anons = Anime
      .where(status: :anons)
      .where(kind: [:tv, :ona])
      .where(episodes_aired: 0)
      .includes(:anime_calendars)
      .references(:anime_calendars)
      .where('anime_calendars.episode = 1 and anime_calendars.start_at < now()')
      .to_a

    anons.delete_if { |v| v.kind_ona? && v.anime_calendars.empty? }

    released = Anime
      .where('released_on >= ?', 2.weeks.ago)
      .where('episodes_aired >= 5')
      .to_a

    (ongoings + anons + released).select do |v|
      !v.kind_special? && !Anime::EXCLUDED_ONGOINGS.include?(v.id) &&
        !TorrentsParser::IGNORED_ANIME_IDS.include?(v.id)
    end
  end

  def self.add_episodes anime, feed
    new_episodes = check_aired_episodes anime, feed

    unless new_episodes.empty?
      print "%d new episodes(s) found for %s\n" % [new_episodes.size, anime.name]
      anime.torrents = (anime.torrents + new_episodes).uniq {|v| v[:title] }
      new_episodes.size
    else
      new_torrents = feed.select {|v| v[:title].match(/x720|x768|720p|x400|400p|x480|480p|x1080|1080p/) }
      unless new_torrents.empty?
        torrents_before = anime.torrents
        torrents_after = ((torrents_before.is_a?(String) ? [] : torrents_before) + new_torrents).
                           select {|v| v.kind_of?(Hash) && v[:title] }.
                           uniq {|v| v[:title] }
        if torrents_before.size != torrents_after.size
          print "%d new torrent(s) found for %s\n" % [torrents_after.size - torrents_before.size, anime.name]
          anime.torrents = torrents_after
        end
      end
      0
    end
  end

  def self.filter_bad_formats(feed)
    feed.select {|v| v[:title].match(/(?:avi|mkv|mp4|\]|[^\.]{5})$/) }
  end

  # добавление новых эпизодов из rss фида
  def self.check_aired_episodes anime, feed
    episode_min = anime.changes['episodes_aired'] || anime.episodes_aired || 0
    episode_max = anime.episodes_aired || 0

    new_episodes = []

    feed
      .each { |v| v[:episodes] = TorrentsParser.extract_episodes_num v[:title] }
      .select { |v| v[:episodes].any? }
      .sort_by { |v| v[:episodes].min }
      .each do |entry|
        next if entry[:episodes].none?

        # для онгоингов и анонсов при нахождении более одного эпизода, игнорируем подобные находки
        episodes_diff = [
          entry[:episodes].min - anime.episodes_aired,
          entry[:episodes].max - anime.episodes_aired
        ].max
        next if entry[:episodes].none?
        next if (anime.ongoing? || anime.anons?) &&
          episodes_diff > entry[:episodes].size &&
          !(entry[:episodes].max > 1 && anime.episodes_aired == 0)
        next if episodes_diff >= 10

        entry[:episodes].each do |episode|
          next if (anime.episodes > 0 && episode > anime.episodes) || episode_min >= episode
          episode_max = episode if episode_max < episode
          new_episodes << entry

          aired_at = (entry[:pubDate] || Time.zone.now) + episode.seconds
          # Shikimori::DOMAIN_LOCALES.each do |locale|
          #   Topics::Generate::News::EpisodeTopic.call(
          #     model: anime,
          #     user: anime.topic_user,
          #     locale: locale,
          #     aired_at: aired_at,
          #     episode: episode
          #   )
          # end

          EpisodeNotification
            .find_or_initialize_by(anime: anime, episode: episode) do |model|
              model.created_at = aired_at
            end
            .update!(is_torrent: true)

          # episodes_aired must be set becase
          # anime object is used in next iterations
          anime.episodes_aired = episode
        end
      end

    # anime.episodes_aired = episode_max
    # anime.save if anime.changed?

    new_episodes.uniq
  end

private_class_method

  def self.get url
    Proxy.get(
      url,
      timeout: 30,
      log: PROXY_LOG,
      no_proxy: true
    )
  end

  def self.ignored_phrases? title
    IGNORED_PHRASES.any? do |phrases|
      phrases.all? { |phrase| title.include? phrase }
    end
  end
end

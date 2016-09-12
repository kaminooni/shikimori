class CharacterProfileSerializer < CharacterSerializer
  attributes :altname, :japanese, :description,
    :description, :description_html, :description_source,
    :favoured?, :thread_id, :topic_id, :updated_at

  has_many :seyu
  has_many :animes
  has_many :mangas

  # TODO: deprecated
  def thread_id
    object.maybe_topic(scope.locale_from_domain).id
  end

  def topic_id
    object.maybe_topic(scope.locale_from_domain).id
  end

  def description
    if scope.ru_domain?
      object[:description_ru] || object[:description_en]
    else
      object[:description_en]
    end
  end

  def description_html
    object.description_html.gsub(%r{(?<!:)//(?=\w)}, 'http://')
  end

  def description_source
    object.source
  end
end
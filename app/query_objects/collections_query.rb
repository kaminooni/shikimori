class CollectionsQuery < SimpleQueryBase
  pattr_initialize :locale

private

  def query
    Collection.where(locale: @locale).order(:id)
  end
end
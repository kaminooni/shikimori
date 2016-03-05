FactoryGirl.define do
  factory :manga do
    sequence(:name) { |n| "manga_#{n}" }
    sequence(:ranked)
    sequence(:russian) { |n| "манга_#{n}" }
    description_ru ''
    description_en ''
    score 1
    mal_scores [1,1,1,1,1,1,1,1,1,1]
    kind :manga

    after(:build) do |anime|
      anime.stub :generate_topic
      anime.stub :generate_name_matches
    end
    trait :with_topic do
      after(:build) do |anime|
        anime.unstub :generate_topic
      end
    end

    Manga.kind.values.each do |kind_type|
      trait kind_type do
        kind kind_type
      end
    end
  end
end
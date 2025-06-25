FactoryBot.define do
  factory :post do
    title { Faker::Lorem.sentence(word_count: 3) }
    content { Faker::Lorem.paragraph(sentence_count: 5) }
    state { 'created' }

    trait :ai_verified do
      state { 'ai_verified' }
    end

    trait :verified do
      state { 'verified' }
    end

    trait :published do
      state { 'published' }
    end

    trait :deleted do
      state { 'deleted' }
    end

    trait :with_long_content do
      content { Faker::Lorem.paragraph(sentence_count: 20) }
    end

    trait :with_short_title do
      title { Faker::Lorem.word }
    end
  end
end 
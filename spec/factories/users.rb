FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@promotion.test" }
    password { '123456' }
  end
end

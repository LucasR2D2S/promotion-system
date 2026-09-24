FactoryBot.define do
  factory :promotion do
    sequence(:name) { |n| "Campanha #{n}" }
    description { 'Promoção de teste' }
    sequence(:code) { |n| "PROMO#{n}" }
    discount_rate { 10 }
    coupon_quantity { 10 }
    expiration_date { 1.month.from_now.to_date }
    user

    # Approval must come from someone other than the creator.
    trait :approved do
      after(:create) { |promotion| promotion.approve!(create(:user)) }
    end

    trait :expired do
      expiration_date { Date.yesterday }
    end
  end
end

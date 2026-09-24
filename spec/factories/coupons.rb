FactoryBot.define do
  factory :coupon do
    sequence(:code) { |n| "CUPOM-#{n.to_s.rjust(4, '0')}" }
    promotion factory: %i[promotion approved]
    status { :able }

    trait :used do
      status { :used }
    end

    trait :disabled do
      status { :disable }
    end
  end
end

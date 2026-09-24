require 'rails_helper'

RSpec.describe CouponGenerationService do
  let(:user) { User.create!(email: 'joao@email.com', password: '123456') }
  let(:promotion) do
    Promotion.create!(name: 'Natal', description: 'Promoção de Natal', code: 'NATAL10',
                      discount_rate: 10, coupon_quantity: 5, expiration_date: 1.month.from_now,
                      user: user)
  end

  it 'generates coupon_quantity unique, non-sequential codes' do
    result = described_class.call(promotion: promotion)

    expect(result).to be_success
    expect(result.value).to eq 5
    codes = promotion.coupons.pluck(:code)
    expect(codes.uniq.size).to eq 5
    expect(codes).to all(match(/\ANATAL10-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}\z/))
    expect(promotion.coupons).to all(be_able)
  end

  it 'is idempotent: a second call has nothing to generate' do
    described_class.call(promotion: promotion)

    result = nil
    expect { result = described_class.call(promotion: promotion) }.not_to change(Coupon, :count)
    expect(result).to be_failure
    expect(result.error).to eq :nothing_to_generate
  end

  it 'only tops up the missing coupons when the quantity is raised' do
    described_class.call(promotion: promotion)
    promotion.update!(coupon_quantity: 8)

    result = described_class.call(promotion: promotion)

    expect(result.value).to eq 3
    expect(promotion.coupons.count).to eq 8
  end

  it 'regenerates codes that collide with existing ones' do
    promotion.update!(coupon_quantity: 2)
    promotion.coupons.create!(code: 'NATAL10-AAAA-AAAA')
    allow(SecureRandom).to receive(:alphanumeric).and_return('AAAAAAAA', 'BBBBBBBB')

    result = described_class.call(promotion: promotion)

    expect(result.value).to eq 1
    expect(promotion.coupons.pluck(:code)).to contain_exactly('NATAL10-AAAA-AAAA', 'NATAL10-BBBB-BBBB')
  end

  it 'inserts in batches instead of one query per coupon' do
    stub_const("#{described_class}::BATCH_SIZE", 2)
    allow(Coupon).to receive(:insert_all).and_call_original

    described_class.call(promotion: promotion)

    expect(Coupon).to have_received(:insert_all).exactly(3).times
    expect(promotion.coupons.count).to eq 5
  end

  it 'gives up instead of looping forever when codes keep colliding' do
    promotion.coupons.create!(code: 'NATAL10-AAAA-AAAA')
    promotion.update!(coupon_quantity: 2)
    allow(SecureRandom).to receive(:alphanumeric).and_return('AAAAAAAA')

    expect { described_class.call(promotion: promotion) }
      .to raise_error(described_class::CodeSpaceExhausted)
  end
end

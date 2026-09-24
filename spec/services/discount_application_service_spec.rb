require 'rails_helper'

RSpec.describe DiscountApplicationService do
  def quote(cart_total, code, **options)
    described_class.call(cart_total:, coupon_code: code, **options)
  end

  def coupon_with_rate(rate)
    create(:coupon, promotion: create(:promotion, :approved, discount_rate: rate))
  end

  describe 'percentage calculation' do
    # [cart total, discount rate %, expected discount, expected final total]
    [
      ['100.00',  10,    '10.00',  '90.00'],
      ['199.90',  30,    '59.97',  '139.93'],
      ['1234.56', 33.33, '411.48', '823.08'],  # 411.478848 -> cents
      ['99.99',   12.5,  '12.50',  '87.49'],   # 12.49875  -> rounds half-up
      ['0.05',    10,    '0.01',   '0.04'],    # 0.005     -> half-up
      ['0.04',    10,    '0.00',   '0.04'],    # 0.004     -> rounds down
      ['250.00',  100,   '250.00', '0.00'],    # never below zero
      ['0',       15,    '0.00',   '0.00']
    ].each do |total, rate, discount, final|
      it "applies #{rate}% to R$ #{total}: discount #{discount}, final #{final}" do
        coupon = coupon_with_rate(rate)

        result = quote(total, coupon.code)

        expect(result).to be_success
        expect(result.value).to have_attributes(
          original_total: BigDecimal(total),
          discount_amount: BigDecimal(discount),
          final_total: BigDecimal(final),
          coupon: coupon
        )
      end
    end

    it 'accepts Integer, Float, BigDecimal and String totals and always returns BigDecimal' do
      code = coupon_with_rate(10).code

      [100, 19.99, BigDecimal('19.99'), '19.99'].each do |total|
        value = quote(total, code).value

        expect([value.original_total, value.discount_amount, value.final_total]).to all(be_a(BigDecimal))
      end
      # 19.99 as a Float must not drift (19.989999... * 10% would round to 1.99)
      expect(quote(19.99, code).value).to have_attributes(discount_amount: BigDecimal('2.00'),
                                                          final_total: BigDecimal('17.99'))
    end

    it 'keeps money invariants for random totals and rates' do
      coupon = coupon_with_rate(10)
      random = Random.new(RSpec.configuration.seed)

      200.times do
        total = BigDecimal(random.rand(0..1_000_000)) / 100        # R$ 0,00 .. R$ 10.000,00
        rate = BigDecimal(random.rand(1..10_000)) / 100            # 0,01% .. 100,00%
        coupon.promotion.update_column(:discount_rate, rate)

        value = quote(total, coupon.code).value
        exact = total * rate / 100

        context = "total=#{total.to_s('F')} rate=#{rate.to_s('F')}"
        expect(value.discount_amount + value.final_total).to eq(total), context
        expect(value.discount_amount).to be_between(0, total), context
        expect((value.discount_amount * 100).frac).to be_zero, "#{context}: not whole cents"
        expect((value.discount_amount - exact).abs).to be <= BigDecimal('0.005'), context
      end
    end
  end

  describe 'expired coupons' do
    it 'does not apply the discount of a promotion that already expired' do
      coupon = create(:coupon, promotion: create(:promotion, :approved, :expired, discount_rate: 50))

      result = quote('100.00', coupon.code)

      expect(result).to be_failure
      expect(result.error).to eq :promotion_expired
      expect(result.value).to be_nil
    end

    it 'is valid until the last minute of the expiration day' do
      coupon = create(:coupon, promotion: create(:promotion, :approved, expiration_date: Date.new(2033, 12, 22)))

      travel_to Time.zone.local(2033, 12, 22, 23, 59, 59) do
        expect(quote('100.00', coupon.code)).to be_success
      end
    end

    it 'expires as soon as the next day starts' do
      coupon = create(:coupon, promotion: create(:promotion, :approved, expiration_date: Date.new(2033, 12, 22)))

      travel_to Time.zone.local(2033, 12, 23, 0, 0, 0) do
        expect(quote('100.00', coupon.code).error).to eq :promotion_expired
      end
    end

    it 'evaluates expiration on an explicit date when given' do
      coupon = create(:coupon, promotion: create(:promotion, :approved, expiration_date: Date.new(2033, 12, 22)))

      expect(quote('100.00', coupon.code, on: Date.new(2033, 12, 22))).to be_success
      expect(quote('100.00', coupon.code, on: Date.new(2033, 12, 23)).error).to eq :promotion_expired
    end
  end

  describe 'other coupons that must not give a discount' do
    {
      'a used coupon' => [-> { create(:coupon, :used) }, :coupon_used],
      'a disabled coupon' => [-> { create(:coupon, :disabled) }, :coupon_disabled],
      'a coupon of an unapproved promotion' => [-> { create(:coupon, promotion: create(:promotion)) },
                                                :promotion_not_approved]
    }.each do |description, (build_coupon, error)|
      it "rejects #{description}" do
        result = quote('100.00', instance_exec(&build_coupon).code)

        expect(result.error).to eq error
        expect(result.value).to be_nil
      end
    end

    it 'rejects unknown and blank codes' do
      expect(quote('100.00', 'NAO-EXISTE').error).to eq :coupon_not_found
      expect(quote('100.00', '   ').error).to eq :coupon_not_found
      expect(quote('100.00', nil).error).to eq :coupon_not_found
    end

    it 'rejects cart totals that are not a valid amount of money' do
      code = coupon_with_rate(10).code

      [nil, '', 'abc', '-0.01', -5, 'NaN', 'Infinity'].each do |total|
        expect(quote(total, code).error).to eq(:invalid_cart_total), "cart_total=#{total.inspect}"
      end
    end
  end

  describe 'integration with MySQL' do
    it 'finds the coupon ignoring case and surrounding whitespace' do
      coupon = create(:coupon, code: 'NATAL10-7KQ2-M9XA')

      expect(quote('100.00', "  natal10-7kq2-m9xa \n").value.coupon).to eq coupon
    end

    it 'keeps fractional rates through the DECIMAL(5,2) column' do
      coupon = coupon_with_rate(12.5)

      # With the old DECIMAL(10,0) column 12.5% was stored as 12% (discount 24.00).
      expect(quote('200.00', coupon.reload.code).value.discount_amount).to eq BigDecimal('25.00')
    end

    it 'is read-only: quoting never changes the coupon' do
      coupon = coupon_with_rate(10)

      expect { quote('100.00', coupon.code) }.not_to(change { coupon.reload.attributes })
    end

    it 'loads coupon, promotion and approval in a single query' do
      coupon = coupon_with_rate(10)
      queries = []
      counter = ->(*, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' || payload[:cached] }

      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { quote('100.00', coupon.code) }

      expect(queries.size).to eq(1), queries.join("\n")
    end
  end
end

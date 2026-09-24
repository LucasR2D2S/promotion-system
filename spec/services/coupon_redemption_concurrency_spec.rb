require 'rails_helper'

# Real concurrency against MySQL: every thread gets its own connection and its own
# transaction. Transactional tests would share one connection across threads and
# the row lock would never be exercised, so this group commits and cleans up.
RSpec.describe CouponRedemptionService, 'under concurrency' do
  self.use_transactional_tests = false

  after do
    [CouponRedemption, Coupon, PromotionApproval, ProductCategoryPromotion, Promotion, User].each(&:delete_all)
  end

  let(:promotion) { create(:promotion, :approved, discount_rate: 10) }

  # Starts all threads, then releases them at the same instant.
  def race(count)
    ActiveRecord::Base.connection_pool.release_connection # leave the pool to the threads
    gate = Concurrent::Event.new
    threads = Array.new(count) do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.wait
          yield i
        end
      end
    end
    gate.set
    threads.map(&:value)
  end

  it 'lets exactly one of several simultaneous checkouts redeem the same coupon' do
    coupon = create(:coupon, promotion:)

    results = race(4) do |i|
      described_class.call(coupon_code: coupon.code, cart_total: '100.00', order_reference: "PED-#{i}")
    end

    expect(results.count(&:success?)).to eq 1
    expect(results.reject(&:success?).map(&:error)).to all(eq(:coupon_used))
    expect(CouponRedemption.where(coupon:).count).to eq 1
  end

  it 'redeems different coupons of the same campaign at the same time' do
    coupons = create_list(:coupon, 4, promotion:)

    results = race(4) do |i|
      described_class.call(coupon_code: coupons[i].code, cart_total: '100.00', order_reference: "PED-#{i}")
    end

    expect(results).to all(be_success)
    expect(CouponRedemption.count).to eq 4
  end

  it 'is not blocked by a lock held on another coupon of the same campaign' do
    locked, free = create_list(:coupon, 2, promotion:)

    holder = hold_lock_on(locked, seconds: 3)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = described_class.call(coupon_code: free.code, cart_total: '100.00', order_reference: 'PED-FREE')
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    holder.join

    expect(result).to be_success
    expect(elapsed).to be < 1
  end

  it 'cancels an order exactly once when two cancellations arrive together' do
    coupon = create(:coupon, promotion:)
    described_class.call(coupon_code: coupon.code, cart_total: '100.00', order_reference: 'PED-1')

    results = race(4) { CouponReleaseService.call(order_reference: 'PED-1') }

    expect(results).to all(be_success)
    expect(results.count { !it.value.replayed }).to eq 1
    expect(coupon.reload).to be_able
  end

  it 'answers :coupon_busy when another checkout holds the coupon longer than the lock timeout' do
    coupon = create(:coupon, promotion:)
    holder = hold_lock_on(coupon, seconds: 3)

    result = ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute('SET SESSION innodb_lock_wait_timeout = 1') # keep the spec fast
      described_class.call(coupon_code: coupon.code, cart_total: '100.00', order_reference: 'PED-WAIT')
    ensure
      connection.execute('SET SESSION innodb_lock_wait_timeout = 5')
    end
    holder.join

    expect(result.error).to eq :coupon_busy
    expect(coupon.reload).to be_able
  end

  # Another "checkout" that locks the coupon row and keeps its transaction open.
  def hold_lock_on(coupon, seconds:)
    ActiveRecord::Base.connection_pool.release_connection
    locked = Concurrent::Event.new
    thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Coupon.transaction do
          Coupon.lock.find(coupon.id)
          locked.set
          sleep seconds
        end
      end
    end
    locked.wait(5)
    thread
  end
end

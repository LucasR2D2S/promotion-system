# Generates the missing coupons of a promotion, up to `promotion.coupon_quantity`.
#
# - Codes are random (e.g. NATAL10-7KQ2-M9XA), not sequential, so valid coupons
#   can't be guessed by incrementing a number. The alphabet skips 0/O and 1/I
#   because customers type these codes by hand.
# - Rows are written with one INSERT per batch instead of one per coupon.
# - The promotion row is locked, so concurrent calls can't overshoot the quantity;
#   running it twice is safe (the second call finds nothing left to generate).
# - Uniqueness is enforced by the UNIQUE index on coupons.code: colliding codes
#   are skipped by the database and regenerated in the next round.
class CouponGenerationService < ApplicationService
  ALPHABET = [*"A".."Z", *"2".."9"] - %w[O I]
  SUFFIX_LENGTH = 8
  BATCH_SIZE = 1_000
  MAX_ROUNDS = 10

  class CodeSpaceExhausted < StandardError; end

  def initialize(promotion:)
    @promotion = promotion
  end

  # Returns ServiceResult with the number of coupons created as value.
  def call
    created = @promotion.with_lock do
      missing = @promotion.coupon_quantity.to_i - @promotion.coupons.count
      next 0 unless missing.positive?

      insert_coupons(missing)
      missing
    end

    created.positive? ? success(created) : failure(:nothing_to_generate)
  end

  private

  def insert_coupons(missing)
    target = @promotion.coupons.count + missing

    MAX_ROUNDS.times do
      remaining = target - @promotion.coupons.count
      return if remaining.zero?

      remaining.clamp(..BATCH_SIZE).then do |batch_size|
        # insert_all on MySQL skips rows that hit a unique index (no-op upsert).
        Coupon.insert_all(build_rows(batch_size))
      end
    end

    raise CodeSpaceExhausted, "could not generate unique codes for promotion #{@promotion.id}"
  end

  def build_rows(size)
    codes = Set.new
    codes << build_code while codes.size < size
    codes.map { |code| { code:, promotion_id: @promotion.id, status: Coupon.statuses[:able] } }
  end

  def build_code
    suffix = SecureRandom.alphanumeric(SUFFIX_LENGTH, chars: ALPHABET)
    "#{@promotion.code}-#{suffix[0, 4]}-#{suffix[4, 4]}".upcase
  end
end

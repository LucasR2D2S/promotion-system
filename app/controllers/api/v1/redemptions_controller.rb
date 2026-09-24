module Api
  module V1
    # Redemptions are addressed by the storefront's order reference, which is also
    # the idempotency key: retrying a request for the same order is always safe.
    #
    #   POST   /api/v1/redemptions                  { coupon_code, cart_total, order_reference }
    #   GET    /api/v1/redemptions/:order_reference
    #   DELETE /api/v1/redemptions/:order_reference  { reason }   (order cancelled: releases the coupon)
    class RedemptionsController < BaseController
      def create
        result = CouponRedemptionService.call(coupon_code: params[:coupon_code], cart_total: params[:cart_total],
                                              order_reference: params[:order_reference])
        render_receipt(result, created_status: :created)
      end

      def show
        redemption = CouponRedemption.includes(:coupon).find_by(order_reference: params[:order_reference])
        return render_error(:order_not_found) unless redemption

        render json: redemption_json(redemption)
      end

      def destroy
        result = CouponReleaseService.call(order_reference: params[:order_reference], reason: params[:reason])
        render_receipt(result, created_status: :ok)
      end

      private

      def render_receipt(result, created_status:)
        return render_error(result.error) if result.failure?

        receipt = result.value
        response.set_header("Idempotent-Replayed", "true") if receipt.replayed
        render json: redemption_json(receipt.redemption), status: receipt.replayed ? :ok : created_status
      end

      def redemption_json(redemption)
        {
          order_reference: redemption.order_reference,
          coupon_code: redemption.coupon.code,
          status: redemption.cancelled? ? "cancelled" : "active",
          original_total: money(redemption.original_total),
          discount_amount: money(redemption.discount_amount),
          final_total: money(redemption.final_total),
          currency: "BRL",
          redeemed_at: redemption.redeemed_at.iso8601,
          cancelled_at: redemption.cancelled_at&.iso8601,
          cancellation_reason: redemption.cancellation_reason
        }
      end
    end
  end
end

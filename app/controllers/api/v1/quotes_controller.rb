module Api
  module V1
    # POST /api/v1/quotes { "coupon_code": "...", "cart_total": "250.00" }
    # Read-only: shows the discount a coupon gives without consuming it.
    class QuotesController < BaseController
      def create
        result = DiscountApplicationService.call(cart_total: params[:cart_total], coupon_code: params[:coupon_code])
        return render_error(result.error) if result.failure?

        quote = result.value
        render json: {
          coupon_code: quote.coupon.code,
          discount_rate: money(quote.coupon.promotion.discount_rate),
          original_total: money(quote.original_total),
          discount_amount: money(quote.discount_amount),
          final_total: money(quote.final_total),
          currency: "BRL"
        }
      end
    end
  end
end

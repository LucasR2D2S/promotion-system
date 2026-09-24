module Api
  module V1
    # JSON API for storefronts: bearer-token auth, per-client rate limit and a
    # stable error contract: { "error": { "code": "coupon_used", "message": "..." } }.
    # Clients branch on `code` (never on `message`, which is for display).
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      # Quotes reveal whether a coupon code exists: without a limit they would
      # let a client enumerate codes.
      RATE_LIMIT_PER_MINUTE = Integer(ENV.fetch("API_RATE_LIMIT_PER_MINUTE", 120))

      ERROR_STATUS = {
        invalid_cart_total: :unprocessable_content,
        invalid_order_reference: :unprocessable_content,
        coupon_used: :unprocessable_content,
        coupon_disabled: :unprocessable_content,
        promotion_expired: :unprocessable_content,
        promotion_not_approved: :unprocessable_content,
        coupon_not_found: :not_found,
        order_not_found: :not_found,
        order_already_has_coupon: :conflict,
        order_cancelled: :conflict,
        coupon_busy: :conflict, # retryable, see Retry-After
        invalid_json: :bad_request,
        unauthorized: :unauthorized,
        rate_limited: :too_many_requests
      }.freeze

      MESSAGE_SCOPES = %w[
        api.errors services.coupon_redemption.errors services.coupon_release.errors
        services.discount_application.errors
      ].freeze

      before_action :authenticate_client!
      rate_limit to: RATE_LIMIT_PER_MINUTE, within: 1.minute, by: -> { @current_client.id },
                 with: -> { render_error(:rate_limited) }

      rescue_from ActionDispatch::Http::Parameters::ParseError do
        render_error(:invalid_json)
      end

      private

      def authenticate_client!
        @current_client = authenticate_with_http_token { |token, _| ApiClient.authenticate(token) }
        return @current_client.track_usage! if @current_client

        response.set_header("WWW-Authenticate", 'Bearer realm="checkout"')
        render_error(:unauthorized)
      end

      def render_error(code)
        response.set_header("Retry-After", "1") if code == :coupon_busy
        render json: { error: { code:, message: error_message(code) } }, status: ERROR_STATUS.fetch(code)
      end

      def error_message(code)
        keys = MESSAGE_SCOPES.map { :"#{it}.#{code}" }
        I18n.t(keys.first, default: keys.drop(1) + [code.to_s.humanize])
      end

      # Money as strings with 2 decimals ("1500.00"): JSON numbers become floats in
      # most clients. Separators are fixed: the app locale (pt-BR) would render
      # "1.500,00", which no client can parse.
      def money(amount)
        ActiveSupport::NumberHelper.number_to_rounded(amount, precision: 2, separator: ".", delimiter: "")
      end
    end
  end
end

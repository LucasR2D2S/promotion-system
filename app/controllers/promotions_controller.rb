class PromotionsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_categories, only: [:new, :create, :edit, :update]

  def index
    @promotions = Promotion.all
  end

  def show
    @promotion = Promotion.find(params[:id])
  end
  
  def new
    @promotion = Promotion.new
  end

  def create
    @promotion = Promotion.new(promotion_params)
    @promotion.user = current_user

    if @promotion.save
      redirect_to @promotion
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @promotion = Promotion.find(params[:id])
  end

  def update
    @promotion = Promotion.find(params[:id])
      if @promotion.update(promotion_params)
        redirect_to @promotion, notice: t('.success')
      else
        render :edit, status: :unprocessable_entity
      end
  end

  def destroy
    @promotion = Promotion.find(params[:id])
    @promotion.destroy

    redirect_to promotions_path, notice: t('.success')
  end

  def generate_coupons
    promotion = Promotion.find(params[:id])
    result = CouponGenerationService.call(promotion: promotion)

    if result.success?
      redirect_to promotion, notice: t('.success', count: result.value)
    else
      redirect_to promotion, alert: t("services.coupon_generation.errors.#{result.error}")
    end
  end

  def approve
    promotion = Promotion.find(params[:id])
    promotion.approve!(current_user)    
    redirect_to promotion
  end

  def search
    @promotions = Promotion.where('name LIKE ?', "%#{Promotion.sanitize_sql_like(params[:q].to_s)}%")
  end

  private
    def load_categories
      @categories = Category.order(:name)
    end

    def promotion_params
      params.require(:promotion).permit(:name, :description, :code, :discount_rate, :coupon_quantity, :expiration_date, category_ids: [])
    end
end
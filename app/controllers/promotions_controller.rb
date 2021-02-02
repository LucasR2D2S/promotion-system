class PromotionsController < ApplicationController
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

    if @promotion.save
      redirect_to @promotion
    else
      render :new
    end
  end

  def edit
    @promotion = Promotion.find(params[:id])
  end

  def update
    @promotion = Promotion.find(params[:id])
      if @promotion.update(promotion_params)
        flash[:success] = "Promoção foi atualizada com sucesso!"
        redirect_to @promotion
      else
        flash[:error] = "Algo deu errado!"
        render 'edit'
      end
  end

  def destroy
    @promotion = Promotion.find(params[:id])
    @promotion.destroy

    flash[:success] = "Promoção foi deletada com sucesso!"

    redirect_to root_path
  end

  def generate_coupons
    @promotion = Promotion.find(params[:id])
    (1..@promotion.coupon_quantity).each do |number|
      Coupon.create!(code: "#{@promotion.code}-#{'%04d' % number}", promotion: @promotion )
    end
    flash[:success] = "Cupons gerados com sucesso"

    redirect_to @promotion
  end

  private
    def promotion_params
      params.require(:promotion).permit(:name, :description, :code, :discount_rate, :coupon_quantity, :expiration_date)
    end
end
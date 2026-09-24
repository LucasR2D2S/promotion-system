require 'rails_helper'

feature 'Admin generate coupons' do
  scenario 'successfully' do
    user = User.create!(email: 'lucas@gmail.com', password: '123456')
    Promotion.create!(name: 'Natal', description: 'Promoção de Natal',
                      code: 'NATAL10', discount_rate: 10, coupon_quantity: 100,
                      expiration_date: '22/12/2033', user: user)

    login_as user, scope: :user
    visit root_path
    click_on 'Promoções'
    click_on 'Natal'
    click_on 'Gerar cupons'

    expect(current_path).to eq(promotion_path(Promotion.last))
    expect(page).to have_content('100 cupons gerados com sucesso')
    expect(page).to have_css('div[id^="coupon-"]', count: 100)
    expect(page).to have_content(/NATAL10-[A-Z2-9]{4}-[A-Z2-9]{4} \(Habilitado\)/)
  end

  scenario 'hide button if coupons generated' do
    user = User.create!(email: 'lucas@gmail.com', password: '123456')
    Promotion.create!(name: 'Natal', description: 'Promoção de Natal',
                      code: 'NATAL10', discount_rate: 10, coupon_quantity: 3,
                      expiration_date: '22/12/2033', user: user)

    login_as user, scope: :user
    visit root_path
    click_on 'Promoções'
    click_on 'Natal'
    click_on 'Gerar cupons'

    expect(page).not_to have_button('Gerar cupons')
  end
end

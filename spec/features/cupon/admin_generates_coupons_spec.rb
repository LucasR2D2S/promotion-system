require 'rails_helper'

feature 'Admin generate coupons' do
  scenario '' do 
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
    expect(page).to have_content('Cupons gerados com sucesso')
    expect(page).to have_content('NATAL10-0001')
    expect(page).to have_content('NATAL10-0050')
    expect(page).to have_content('NATAL10-0100')
    expect(page).not_to have_content('NATAL10-0101')
  end
  # TODO: fazer esse teste
  xscenario 'hide button if coupons generated' do
  end
end

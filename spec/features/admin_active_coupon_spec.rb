require 'rails_helper'

feature 'Admin active coupon' do 
  scenario 'succesfully' do
    user = User.create!(email: 'lucas@gmail.com', password: '123456')
    promotion = Promotion.create!(name: 'Natal', description: 'Promoção de Natal',
                      code: 'NATAL10', discount_rate: 10, coupon_quantity: 100,
                      expiration_date: '22/12/2033', user: user)
    coupon = Coupon.create!(code: 'ABC0001', promotion: promotion)

    login_as user, scope: :user
    visit root_path
    click_on 'Promoções'
    click_on promotion.name
    click_on 'Desabilitar'
    click_on 'Habilitar'

    coupon.reload
    expect(page).to have_content('ABC0001 (Habilitado)')
    expect(coupon).to be_able
  end

  scenario 'button appeared' do
    user = User.create!(email: 'lucas@gmail.com', password: '123456')
    promotion = Promotion.create!(name: 'Natal', description: 'Promoção de Natal',
                      code: 'NATAL10', discount_rate: 10, coupon_quantity: 100,
                      expiration_date: '22/12/2033', user: user)
    coupon = Coupon.create!(code: 'ABC0001', promotion: promotion)

    login_as user, scope: :user
    visit root_path
    click_on 'Promoções'
    click_on promotion.name
    click_on 'Desabilitar' 

    coupon.reload
    expect(page).to have_link('Habilitar')
  end
end
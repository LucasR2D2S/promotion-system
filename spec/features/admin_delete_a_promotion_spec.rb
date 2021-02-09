require 'rails_helper'

feature 'Admin delete a promotion' do 
  scenario 'promotion is destroyed' do
    user = User.create!(email: 'lucas@gmail.com', password: '123456')
    promotion = Promotion.create!(name: 'Natal', description: 'Promoção de Natal',
                      code: 'NATAL10', discount_rate: 10, coupon_quantity: 100,
                      expiration_date: '22/12/2033', user: user)

    #promotion.destroy!
    login_as user, scope: :user
    visit root_path
    click_on 'Promoções'
    click_on 'Natal'

    expect { click_link 'Apagar promoção' }.to change(Promotion, :count).by(-1)    
    expect(page).to have_content 'Promoção e seus cupons foram apagados com sucesso!'
  end
end
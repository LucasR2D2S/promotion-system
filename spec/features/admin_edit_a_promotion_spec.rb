require 'rails_helper'

feature 'Admin edit a promotion' do
  scenario 'successfully' do 
    user = User.create!(email: 'lucas@gmail.com', password: '123456')
    promotion = Promotion.create!(name: 'Natal', description: 'Promoção de Natal',
                      code: 'NATAL10', discount_rate: 10, coupon_quantity: 100,
                      expiration_date: '22/12/2033', user: user)

    login_as user, scope: :user
    visit root_path
    click_on 'Promoções'
    click_on 'Natal'
    click_on 'Editar promoção'
    fill_in 'Nome', with: 'Natal21'
    fill_in 'Código', with: 'NATAL21'
    fill_in 'Desconto', with: '21'
    fill_in 'Data de término', with: '26-12-2021'
    click_on 'Enviar'

    expect(current_path).to eq(promotion_path(Promotion.last))
    expect(page).to have_content('Natal21')
    expect(page).to have_content('NATAL21')
    expect(page).to have_content('21')
    expect(page).to have_content('26/12/2021')
  end

end
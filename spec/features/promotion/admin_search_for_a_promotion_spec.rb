require 'rails_helper'

feature 'Visit home page' do
  context 'and search for promotion' do
    scenario 'and must be signed in' do
      visit root_path
  
      expect(current_path).to eq new_user_session_path
    end

    scenario 'successfully' do
      user = User.create!(email: 'lucas@gmail.com', password: '123456')
      promotion = Promotion.create!(name: 'Natal', description: 'Promoção de Natal',
                      code: 'NATAL10', discount_rate: 10, coupon_quantity: 100,
                      expiration_date: '22/12/2033', user: user)
      promotion = Promotion.create!(name: 'Navalha', description: 'Navalha baratinha',
                      code: 'NA20', discount_rate: 20, coupon_quantity: 75,
                      expiration_date: '25/12/2033', user: user)
      promotion = Promotion.create!(name: 'Especial', description: 'Promoção de Especial',
                      code: 'ES20', discount_rate: 20, coupon_quantity: 75,
                      expiration_date: '25/12/2033', user: user)

      login_as user, scope: :user
      visit root_path
      click_on 'Promoções'
      fill_in 'Procurar promoção:', with: 'Na'
      find('div#searchPro').click_on 'Pesquisar'

      expect(current_path).to eq search_path
      expect(page).to have_content('Natal')
      expect(page).to have_content('Promoção de Natal')
      expect(page).to have_content('Navalha')
      expect(page).to have_content('Navalha baratinha')
      expect(page).not_to have_content('Especial')
      expect(page).not_to have_content('Promoção de Especial')
    end
  end
end
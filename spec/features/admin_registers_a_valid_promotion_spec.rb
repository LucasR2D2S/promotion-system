require 'rails_helper'

feature 'Admin registers a valid promotion' do
  scenario 'and attributes cannot be blank' do
    user = User.create!(email: 'lucas@gmail.com', password: '123456')

    login_as user, scope: :user
    visit root_path
    click_on 'Promoções'
    click_on 'Registrar uma promoção'
    fill_in 'Nome', with: ''
    fill_in 'Descrição', with: ''
    fill_in 'Código', with: ''
    fill_in 'Desconto', with: ''
    fill_in 'Quantidade de cupons', with: ''
    fill_in 'Data de término', with: ''
    click_on 'Enviar'

    expect(Promotion.count).to eq 0
    expect(page).to have_content('Não foi possível cadastrar a promoção.')
    expect(page).to have_content('não pode ficar em branco', count: 5)
  end

  scenario 'and code must be unique' do
    user = User.create!(email: 'lucas@gmail.com', password: '123456')
    promotion = Promotion.create!(name: 'Natal', description: 'Promoção de Natal',
                      code: 'NATAL10', discount_rate: 10, coupon_quantity: 100,
                      expiration_date: '22/12/2033', user: user)

    login_as user, scope: :user
    visit root_path
    click_on 'Promoções'
    click_on 'Registrar uma promoção'
    fill_in 'Código', with: 'NATAL10'
    click_on 'Enviar'

    expect(page).to have_content('deve ser único')
  end
end
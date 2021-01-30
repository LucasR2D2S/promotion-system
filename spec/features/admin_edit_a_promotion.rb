require 'rails_helper'

feature 'Admin edit a promotion' do
  scenario 'from index' do 
    Promotion.create!(name: 'Natal', description: 'Promoção de Natal',
                      code: 'NATAL10', discount_rate: 10, coupon_quantity: 100,
                      expiration_date: '22/12/2033')

    visit root_path
    click_on 'Promoções'
    click_on 'Editar Promoção'
    fill_in 'Nome', with: 'Natal21'
    fill_in 'Descrição', with: 'Promoção de Natal Radical'
    fill_in 'Código', with: 'NATAL21'
    fill_in 'Desconto', with: '21'
    fill_in 'Quantidade de cupons', with: '200'
    fill_in 'Data de término', with: '26-12-2021'
    click_on 'Enviar'

    

  end
end
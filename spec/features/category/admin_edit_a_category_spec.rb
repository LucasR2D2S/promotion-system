require 'rails_helper'

feature 'Admin edit a  category' do
  scenario 'must be signed in' do
    visit root_path

    expect(current_path).to eq new_user_session_path
  end

  scenario 'succefully' do
    user = User.create!(email: 'lucas@gmail.com', password: '123456')
    category = Category.create!(name: 'Natalinas', code: 'NATAL')
                    
    login_as user, scope: :user
    visit root_path
    click_on 'Categorias de promoções'
    click_on 'Natalinas'
    click_on 'Editar categoria'
    fill_in "Nome",	with: "Natalinas Especial" 
    fill_in "Código",	with: "NATALES" 
    click_on 'Enviar'

    # expect(current_path).to eq (Category.last)_path
    expect(page).to have_content 'Natalinas Especial'
    expect(page).to have_content 'NATALES'
  end
end

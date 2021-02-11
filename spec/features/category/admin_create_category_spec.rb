require 'rails_helper'

feature 'Admin create category' do
  scenario 'must be signed in' do
    visit root_path

    expect(current_path).to eq new_user_session_path
  end

  scenario 'succefully' do
    user = User.create!(email: 'lucas@gmail.com', password: '123456')
                    
    login_as user, scope: :user
    visit root_path
    click_on 'Categorias de promoções'
    click_on 'Criar nova categoria'
    fill_in "Nome",	with: "Natalinas" 
    fill_in "Código",	with: "NATAL" 
    click_on 'Enviar'

    # expect(current_path).to eq (Category.last)_path
    expect(page).to have_content 'Natalinas'
    expect(page).to have_content 'NATAL'
  end
end
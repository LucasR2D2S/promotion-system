require 'rails_helper'

feature 'User sign in' do
  scenario 'succeefully' do
    user = User.create!(email: 'lucas@email.com', password: '123456')

    visit root_path
    click_on 'Entrar'
    withing('form') do
      fill_in 'E-mail', with user.email
      fill_in 'Senha', with '123456'
      click_on 'Entrar'
    end

    expect(page).to have_content user.email
    expect(page).to have_content 'Login efetuado com sucesso'
    expect(page).to have_content 'Sair'
    expect(page).not_to have_content 'Entrar'
  end
end

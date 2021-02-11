require 'rails_helper'

feature 'Visitor visit home page' do
  scenario 'successfully' do
    user = User.create!(email: 'lucas@gmail.com', password: '123456')
    login_as user, scope: :user
    visit root_path

    expect(page).to have_content('Promotion System')
    expect(page).to have_content('Boas vindas ao sistema de gestão de '\
                                 'promoções')
  end
end

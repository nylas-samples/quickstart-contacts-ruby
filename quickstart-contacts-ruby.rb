# frozen_string_literal: true

require 'nylas'
require 'dotenv/load'
require 'sinatra'

set :show_exceptions, :after_handler
enable :sessions

error 404 do
  'No authorization code returned from Nylas'
end

error 500 do
  'Failed to exchange authorization code for token'
end

nylas = Nylas::Client.new(
  api_key: ENV['NYLAS_API_KEY'],
  api_uri: ENV['NYLAS_API_URI']
)

get '/nylas/auth' do
  config = {
    client_id: ENV['NYLAS_CLIENT_ID'],
    provider: 'google',
    redirect_uri: 'http://localhost:4567/oauth/exchange',
    login_hint: 'atejada@gmail.com',
    access_type: 'offline'
  }

  url = nylas.auth.url_for_oauth2(config)
  redirect url
end

get '/oauth/exchange' do
  code = params[:code]
  status 404 if code.nil?

  begin
    response = nylas.auth.exchange_code_for_token({
                                                    client_id: ENV['NYLAS_CLIENT_ID'],
                                                    redirect_uri: 'http://localhost:4567/oauth/exchange',
                                                    code: code
                                                  })
  rescue StandardError
    status 500
  else
    response[:grant_id]
    response[:email]
    session[:grant_id] = response[:grant_id]
  end
end

get '/nylas/list-contacts' do
  query_params = { limit: 5 }
  contacts, _request_ids = nylas.contacts.list(identifier: session[:grant_id],
                                               query_params: query_params)
  contacts.to_json
rescue StandardError => e
  e.to_s
end

get '/nylas/create-contact' do
  request_body = {
    given_name: 'My',
    middle_name: 'Nylas',
    surname: 'Friend',
    emails: [{ email: 'swag@nylas.com', type: 'work' }],
    notes: 'Make sure to keep in touch!',
    phone_numbers: [{ number: '555 555-5555', type: 'business' }],
    web_pages: [{ url: 'https://www.nylas.com', type: 'homepage' }]
  }

  contact, = nylas.contacts.create(identifier: session[:grant_id],
                                   request_body: request_body)
  contact.to_json
rescue StandardError => e
  e.to_s
end

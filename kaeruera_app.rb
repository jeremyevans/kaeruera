require 'erb'
require 'sinatra/base'
require 'rack/csrf'
require 'models'
require 'json'
require './lib/kaeruera/recorder'

module KaeruEra
  class App < Sinatra::Base
    KE = Recorder.new(DB, 'kaeruera', 'kaeruera')

    set :environment, 'production'
    disable :run
    use Rack::Session::Cookie, :secret=>File.file?('kaeruera.secret') ? File.read('kaeruera.secret') : (ENV['KAERUERA_SECRET'] || SecureRandom.hex(20))
    use Rack::Csrf, :skip => ['POST:/report_error']

    def h(text)
      Rack::Utils.escape_html(text)
    end

    before do
      unless %w'/application.css /favicon.ico /login /logout /report_error'.include?(env['PATH_INFO'])
        redirect('/login', 303) if !session[:user_id]
      end
    end

    error do
      KE.record(:params=>params, :env=>env, :session=>session, :error=>request.env['sinatra.error'])
    end

    get '/login' do
      render :erb, :login
    end
    post '/login' do
      if i = User.login_user_id(params[:email].to_s, params[:password].to_s)
        session[:user_id] = i
        redirect('/', 303)
      else
        redirect('/login', 303)
      end
    end
    
    post '/logout' do
      session.clear
      redirect '/login'
    end

    get '/change_password' do
      erb :change_password
    end
    post '/change_password' do
      user = User.with_pk!(session[:user_id])
      user.password = params[:password].to_s
      user.save
      redirect('/', 303)
    end

    get '/add_application' do
      erb :add_application
    end
    post '/add_application' do
      Application.create(:user_id=>session[:user_id], :name=>params[:name])
      redirect('/', 303)
    end

    get '/' do
      @apps = Application.where(:user_id=>session[:user_id]).order(:name).all
      erb :applications
    end

    get '/applications/:application_id' do
      @errors = Error.where(:application_id=>params[:application_id].to_i).most_recent(25).all
      erb :errors
    end
    get '/error/:id' do
      @error = Error.with_pk!(params[:id].to_i)
      erb :error
    end

    get '/search' do
      if search = params[:search]
        @errors = Error.where(:application=>Application.where(:user_id=>session[:user_id])).search(search.to_s).most_recent(25).all
        erb :errors
      else
        erb :search
      end
    end

    post '/report_error' do
      params = JSON.parse(request.body.read)
      data = params['data']
      app_id = Application.first!(:token=>params['token'].to_s, :id=>params['id'].to_i).id

      h = {
        :application_id=>app_id,
        :error_class=>data['error_class'],
        :message=>data['message'],
        :backtrace=>Sequel.pg_array(data['backtrace'])
      }

      if v = data['params']
        h[:params] = Sequel.pg_json(v)
      end
      if v = data['session']
        h['session'] = Sequel.pg_json(v)
      end
      if v = data['env']
        h[:env] = Sequel.hstore(v)
      end

      error_id = DB[:errors].insert(h)
      "{\"error_id\": #{error_id}}"
    end
  end
end

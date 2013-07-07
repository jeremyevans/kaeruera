require 'erb'
require 'sinatra/base'
require 'rack/csrf'
require 'models'
require 'json'
require 'forme/sinatra'
require 'sinatra/flash'
$: << './lib'
require 'kaeruera/database_reporter'

Forme.register_config(:mine, :base=>:default, :serializer=>:html_usa, :labeler=>:explicit, :wrapper=>:div)
Forme.default_config = :mine

module KaeruEra
  class App < Sinatra::Base
    # The reporter used for reporting internal errors.  Defaults to the same database
    # used to store the errors for the applications that this server tracks.  This
    # causes obvious issues if the Database for this server goes down.
    REPORTER = (DatabaseReporter.new(DB, ENV['KAERUERA_INTERNAL_ERROR_USER']||'kaeruera', 'KaeruEraApp') rescue nil)

    # The number of errors to show per page on the application and search result pages.
    # Currently hardcoded, but will probably be made user specific at some point.
    PER_PAGE = 25

    # Whether demo is on.  In demo mode, passwords cannot be changed.
    if ENV['DEMO_MODE'] == '1'
      DEMO_MODE = true
    else
      DEMO_MODE = false
    end

    set :environment, 'production'
    disable :run
    use Rack::Session::Cookie, :secret=>File.file?('kaeruera.secret') ? File.read('kaeruera.secret') : (ENV['KAERUERA_SECRET'] || SecureRandom.hex(20))
    use Rack::Csrf, :skip => ['POST:/report_error']
    register Sinatra::Flash
    helpers Forme::Sinatra::ERB

    def h(text)
      Rack::Utils.escape_html(text)
    end

    def url_escape(text)
      Rack::Utils.escape(text)
    end

    # Returns a dataset of all applications for the logged in user.
    def user_apps
      Application.with_user(session[:user_id])
    end

    # Returns the application with the given id for the logged in user.
    def get_application
      @app = Application.first!(:user_id=>session[:user_id], :id=>params[:application_id].to_i)
    end

    # Returns the application with the given id for the logged in user.
    def get_error
      @error = Error.with_user(session[:user_id]).first!(:id=>params[:id].to_i)
    end

    # Does a simple pagination of the results of the dataset.  This
    # increases the per page limit by one, and if that number of rows
    # are returned, it is obvious that there is another page.  This is
    # faster than a normal paginator, which requires a count of matching
    # rows, but doesn't allow for jumping more than one page forward at a time.
    def paginator(dataset, per_page=PER_PAGE)
      return dataset.all if params[:all] == '1'
      page = (params[:page] || 1).to_i
      page = 1 if page < 1
      @previous_page = true if page > 1
      @page = page
      offset = (page - 1) * per_page
      values = dataset.limit(per_page+1, offset > 0 ? offset : nil).all
      if values.length == per_page+1
        values.pop
        @next_page = true
      end
      values
    end

    # Return a path to a different page in the same paginated
    # result set.
    def modify_page(i)
      query = env['QUERY_STRING']
      found_page = false
      if query && !query.empty?
        query = query.sub(/page=(\d+)(\z|&)/) do
          found_page = true
          "page=#{$1.to_i+i}#{$2}"
        end 
        if found_page == false && i == 1
          query += "&page=2"
        end
      elsif i == 1
        query = "page=2"
      end

      "#{env['PATH_INFO']}?#{query}"
    end

    # Return an html fragment for the Previous Page button, if this
    # isn't the first page.
    def previous_page
      return unless @previous_page
      "<a class='btn' href=\"#{modify_page(-1)}\">Previous Page</a>"
    end

    # Return a html fragment for the Next Page button, if there is a
    # another page.
    def next_page
      return unless @next_page
      "<a class='btn' href=\"#{modify_page(1)}\">Next Page</a>"
    end

    # Force users to login before using the site, except for error
    # reporting (which uses the application's token).
    before do
      unless %w'/application.css /favicon.ico /login /logout /report_error'.include?(env['PATH_INFO'])
        redirect('/login', 303) if !session[:user_id]
      end
    end

    # If an internal error occurs, record it so that the application
    # can track its own errors.
    error do
      if REPORTER
        REPORTER.report(:params=>params, :env=>env, :session=>session, :error=>request.env['sinatra.error'])
      end
      erb("Sorry, an error occurred")
    end

    get '/login' do
      render :erb, :login
    end

    post '/login' do
      if i = User.login_user_id(params[:email].to_s, params[:password].to_s)
        session[:user_id] = i
        flash[:notice] = "Logged In"
        redirect('/', 303)
      else
        flash[:error] = "No matching email/password"
        redirect('/login', 303)
      end
    end
    
    post '/logout' do
      session.clear
      flash[:notice] = "Logged Out"
      redirect '/login'
    end

    unless DEMO_MODE
      get '/change_password' do
        erb :change_password
      end

      post '/change_password' do
        user = User.with_pk!(session[:user_id])
        user.password = params[:password].to_s
        user.save
        flash[:notice] = "Password Changed"
        redirect('/', 303)
      end
    end

    get '/add_application' do
      erb :add_application
    end

    post '/add_application' do
      Application.create(:user_id=>session[:user_id], :name=>params[:name])
      flash[:notice] = "Application Added"
      redirect('/', 303)
    end

    get '/' do
      @apps = user_apps.order(:name).all
      erb :applications
    end

    get '/applications/:application_id/reporter_info' do
      get_application
      erb :reporter_info
    end

    get '/applications/:application_id/errors' do
      get_application
      @errors = paginator(@app.app_errors_dataset.open.most_recent)
      erb :errors
    end

    get '/error/:id' do
      @error = get_error
      erb :error
    end

    post '/update_error/:id' do
      @error = get_error
      halt(403, erb("Error Not Open")) if @error.closed
      @error.closed = true if params[:close] == '1'
      @error.update(:notes=>params[:notes].to_s)
      flash[:notice] = "Error Updated"
      redirect("/error/#{@error.id}")
    end

    post '/update_multiple_errors' do
      h = {:notes=>params[:notes].to_s}
      h[:closed] = true if params[:close] == '1'
      n = Error.
        with_user(session[:user_id]).
        where(:id=>params[:ids].to_a.map{|x| x.to_i}, :closed=>false).
        update(h)
      flash[:notice] = "Updated #{n} errors"
      redirect("/")
    end

    get '/search' do
      if search = params[:search]
        @errors = paginator(Error.search(params, session[:user_id]).most_recent)
        erb :errors
      else
        @apps = user_apps.order(:name).all
        erb :search
      end
    end

    post '/report_error' do
      params = JSON.parse(request.body.read)
      data = params['data']
      halt(404, "No matching application") unless app = Application.first!(:token=>params['token'].to_s, :id=>params['id'].to_i)

      h = {
        :user_id=>app.user_id,
        :application_id=>app.id,
        :error_class=>data['error_class'],
        :message=>data['message'],
        :backtrace=>Sequel.pg_array(data['backtrace'])
      }

      if v = data['params']
        h[:params] = Sequel.pg_json(v.to_hash)
      end
      if v = data['session']
        h['session'] = Sequel.pg_json(v.to_hash)
      end
      if v = data['env']
        h[:env] = Sequel.hstore(v.to_hash)
      end

      error_id = DB[:errors].insert(h)
      "{\"error_id\": #{error_id}}"
    end
  end
end

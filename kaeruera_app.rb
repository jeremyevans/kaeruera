require 'rubygems'
require 'roda'
require './models'
require 'rack/indifferent'
$: << './lib'
require 'kaeruera/database_reporter'

begin
  require 'tilt/erubis'
rescue LoadError
  require 'tilt/erb'
end

module KaeruEra
  class App < Roda
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

    use Rack::Session::Cookie, :secret=>File.file?('kaeruera.secret') ? File.read('kaeruera.secret') : (ENV['KAERUERA_SECRET'] || SecureRandom.hex(20))
    plugin :csrf, :skip => ['POST:/report_error']

    plugin :not_found
    plugin :error_handler
    plugin :render, :escape=>true, :cache=>ENV['RACK_ENV'] != 'development'
    plugin :assets,
      :css=>%w'bootstrap.min.css application.scss',
      :css_opts=>{:style=>:compressed, :cache=>false},
      :css_dir=>nil,
      :compiled_path=>nil,
      :compiled_css_dir=>nil,
      :precompiled=>'compiled_assets.json',
      :prefix=>nil
    plugin :flash
    plugin :h
    plugin :halt
    plugin :json
    plugin :forme
    plugin :symbol_matchers
    plugin :symbol_views
    plugin :delegate
    request_delegate :params

    Forme.register_config(:mine, :base=>:default, :serializer=>:html_usa, :labeler=>:explicit, :wrapper=>:div)
    Forme.default_config = :mine

    def url_escape(text)
      Rack::Utils.escape(text)
    end

    # Returns a dataset of all applications for the logged in user.
    def user_apps
      Application.with_user(session[:user_id])
    end

    # Returns the application with the given id for the logged in user.
    def get_error(id)
      @error = Error.with_user(session[:user_id]).first!(:id=>id.to_i)
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

    # If an internal error occurs, record it so that the application
    # can track its own errors.
    error do |e|
      if REPORTER
        REPORTER.report(:params=>request.params, :env=>env, :session=>session, :error=>e)
      end
      #$stderr.puts e.class, e.message, e.backtrace
      view(:content=>"Sorry, an error occurred")
    end

    route do |r|
      r.assets

      r.is 'login' do
        r.get do
          :login
        end

        r.post do
          if i = User.login_user_id(params[:email].to_s, params[:password].to_s)
            session[:user_id] = i
            flash[:notice] = "Logged In"
            r.redirect('/')
          else
            flash[:error] = "No matching email/password"
            r.redirect
          end
        end
      end
      
      r.post 'logout' do
        session.clear
        flash[:notice] = "Logged Out"
        r.redirect '/login'
      end

      r.post 'report_error' do
        params = JSON.parse(request.body.read)
        data = params['data']
        r.halt(404, "No matching application") unless app = Application.first!(:token=>params['token'].to_s, :id=>params['id'].to_i)

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

        {'error_id' => DB[:errors].insert(h)}
      end

      # Force users to login before using the site, except for error
      # reporting (which uses the application's token).
      r.redirect('/login') unless session[:user_id]

      unless DEMO_MODE
        r.is 'change_password' do
          r.get do
            :change_password
          end

          r.post do
            user = User.with_pk!(session[:user_id])
            user.password = params[:password].to_s
            user.save
            flash[:notice] = "Password Changed"
            r.redirect('/')
          end
        end
      end

      r.is 'add_application' do
        r.get do
          :add_application
        end

        r.post do
          Application.create(:user_id=>session[:user_id], :name=>params[:name])
          flash[:notice] = "Application Added"
          r.redirect('/', 303)
        end
      end

      r.get do
        r.is "" do
          @apps = user_apps.order(:name).all
          :applications
        end

        r.on 'applications/:d' do |id|
          @app = Application.first!(:user_id=>session[:user_id], :id=>id.to_i)

          r.is 'reporter_info' do
            :reporter_info
          end

          r.is 'errors' do
            @errors = paginator(@app.app_errors_dataset.open.most_recent)
            :errors
          end
        end

        r.is 'error/:d' do |id|
          @error = get_error(id)
          :error
        end

        r.is 'search' do
          if search = r['search']
            @errors = paginator(Error.search(params, session[:user_id]).most_recent)
            :errors
          else
            @apps = user_apps.order(:name).all
            :search
          end
        end
      end

      r.post do
        r.is 'update_error/:d' do |id|
          @error = get_error(id)
          r.halt(403, view(:content=>"Error Not Open")) if @error.closed
          @error.closed = true if params[:close] == '1'
          @error.update(:notes=>params[:notes].to_s)
          flash[:notice] = "Error Updated"
          r.redirect("/error/#{@error.id}")
        end

        r.is 'update_multiple_errors' do
          h = {:notes=>params[:notes].to_s}
          h[:closed] = true if params[:close] == '1'
          n = Error.
            with_user(session[:user_id]).
            where(:id=>params[:ids].to_a.map(&:to_i), :closed=>false).
            update(h)
          flash[:notice] = "Updated #{n} errors"
          r.redirect("/")
        end
      end
    end
  end
end

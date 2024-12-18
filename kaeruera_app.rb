# frozen_string_literal: true
require_relative 'models'
require_relative 'lib/kaeruera/database_reporter'
require 'roda'

require 'tilt'
require 'tilt/erubi'
require 'tilt/string'
require 'erubi/capture_block'

module KaeruEra
  class App < Roda
    def self.freeze
      KaeruEra::Model.freeze_descendents
      KaeruEra::DB.freeze
      super
    end

    opts[:root] = File.dirname(__FILE__)
    opts[:check_dynamic_arity] = false
    opts[:check_arity] = :warn

    # The reporter used for reporting internal errors.  Defaults to the same database
    # used to store the errors for the applications that this server tracks.  This
    # causes obvious issues if the Database for this server goes down.
    opts[:internal_errors] = {:reporter => (DatabaseReporter.new(DB, ENV['KAERUERA_INTERNAL_ERROR_USER']||'kaeruera', 'KaeruEraApp') rescue nil)}

    # The number of errors to show per page on the application and search result pages.
    # Currently hardcoded, but will probably be made user specific at some point.
    PER_PAGE = 25

    # Whether demo is on.  In demo mode, passwords cannot be changed.
    if ENV['KAERUERA_DEMO_MODE'] == '1'
      DEMO_MODE = true
    else
      DEMO_MODE = false
    end

    plugin :public
    plugin :route_csrf
    plugin :direct_call
    plugin :not_found
    plugin :error_handler
    plugin :render, :escape=>true, :template_opts=>{:chain_appends=>true, :freeze=>true, :skip_compiled_encoding_detection=>true, :engine_class=>Erubi::CaptureBlockEngine}
    plugin :assets,
      :css=>%w'application.scss',
      :css_opts=>{:style=>:compressed, :cache=>false},
      :css_dir=>nil,
      :compiled_path=>nil,
      :compiled_css_dir=>nil,
      :precompiled=>File.expand_path('../compiled_assets.json', __FILE__),
      :prefix=>nil,
      :gzip=>true
    plugin :flash
    plugin :h
    plugin :r
    plugin :halt
    plugin :json
    plugin :forme_set, secret: ENV['KAERUERA_SESSION_SECRET']
    plugin :forme_erubi_capture_block
    plugin :symbol_views
    plugin :request_aref, :raise
    plugin :disallow_file_uploads
    plugin :Integer_matcher_max
    plugin :typecast_params_sized_integers, :sizes=>[64], :default_size=>64
    alias tp typecast_params

    logger = if ENV['MULTITHREADED_TRANSACTIONAL_TEST']
      Logger.new('spec/puma.test.log')
    elsif ENV['RACK_ENV'] == 'test'
      Class.new{def write(_) end}.new
    else
      $stderr
    end
    plugin :common_logger, logger

    if ENV['RACK_ENV'] == 'development'
      plugin :exception_page
      class RodaRequest
        def assets
          exception_page_assets
          super
        end
      end
    end

    plugin :sessions, :secret=>ENV.delete('KAERUERA_SESSION_SECRET'), :key=>'kaeruera.session'

    Forme.register_config(:mine, :base=>:default, :serializer=>:html_usa, :labeler=>:explicit, :wrapper=>:div)
    Forme.default_config = :mine

    def url_escape(text)
      Rack::Utils.escape(text)
    end

    # Returns a dataset of all applications for the logged in user.
    def user_apps
      Application.with_user(session['user_id'])
    end

    # Does a simple pagination of the results of the dataset.  This
    # increases the per page limit by one, and if that number of rows
    # are returned, it is obvious that there is another page.  This is
    # faster than a normal paginator, which requires a count of matching
    # rows, but doesn't allow for jumping more than one page forward at a time.
    def paginator(dataset, per_page=PER_PAGE)
      return dataset.all if tp.bool('all')
      page = tp.pos_int('page', 1)
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
      case e
      when Roda::RodaPlugins::TypecastParams::Error
        response.status = 400
        view(:content=>"<h1>Invalid parameter submitted: #{h e.param_name}</h1>")
      else
        if reporter = opts[:internal_errors][:reporter]
          reporter.report(:params=>r.params, :env=>env, :session=>session, :error=>e)
        end
        $stderr.puts "#{e.class}: #{e.message}", e.backtrace unless ENV['RACK_ENV'] == 'test'
        next exception_page(e, :assets=>true) if ENV['RACK_ENV'] == 'development'
        view(:content=>"<h1>Internal Server Error</h1>")
      end
    end

    plugin :rodauth, :csrf=>:route_csrf do
      db DB
      enable :login, :logout, :change_password
      session_key 'user_id'
      login_param 'email'
      login_label 'Email'
      login_column :email
      accounts_table :users
      account_password_hash_column :password_hash
      title_instance_variable :@title
      if DEMO_MODE
        login_input_type 'text'
        before_change_password{r.halt(404)}
      end
    end

    plugin :content_security_policy do |csp|
      csp.default_src :none
      csp.style_src :self, :unsafe_inline
      csp.img_src :self
      csp.form_action :self
      csp.base_uri :none
      csp.frame_ancestors :none
    end

    plugin :class_matchers
    class_matcher Application, Integer do |id|
      Application.first(:user_id=>session['user_id'], :id=>id)
    end
    class_matcher Error, Integer do |id|
      Error.first(:user_id=>session['user_id'], :id=>id)
    end

    route do |r|
      r.post 'report_error' do
        params = JSON.parse(r.body.read)
        data = params['data']
        r.halt(404, "No matching application") unless app = Application.first!(:token=>params['token'].to_s, :id=>params['id'].to_i)

        h = {
          :user_id=>app.user_id,
          :application_id=>app.id,
          :error_class=>data['error_class'],
          :message=>data['message'],
          :backtrace=>Sequel.pg_array(data['backtrace'], :text)
        }

        if v = data['params']
          h[:params] = Sequel.pg_jsonb(v.to_hash)
        end
        if v = data['session']
          h[:session] = Sequel.pg_jsonb(v.to_hash)
        end
        if v = data['env']
          h[:env] = Sequel.pg_jsonb(v.to_hash)
        end

        {'error_id' => DB[:errors].insert(h)}
      end

      r.assets
      r.public
      r.rodauth
      check_csrf!
      rodauth.require_authentication

      r.is 'add_application' do
        @app = Application.new(:user_id=>session['user_id'])

        r.get do
          :add_application
        end

        r.post do
          forme_set(@app).save
          flash['notice'] = "Application Added"
          r.redirect('/', 303)
        end
      end

      r.root do
        @apps = user_apps.order(:name).all
        :applications
      end

      r.on 'applications', Application do |app|
        @app = app

        r.get 'reporter_info' do
          :reporter_info
        end

        r.get 'errors' do
          @errors = paginator(@app.app_errors_dataset.open.most_recent)
          :errors
        end
      end

      r.get 'error', Error do |error|
        @error = error
        :error
      end

      r.get 'search' do
        if search = tp.nonempty_str('search')
          search_opts = tp.convert!(:symbolize=>true) do |tp|
            tp.pos_int(%w'application')
            tp.nonempty_str(%w'error_class message backtrace field key field_type value')
            tp.bool('closed')
            tp.time(%w'occurred_after occurred_before')
          end
          @errors = paginator(Error.search(search_opts, session['user_id']).most_recent)
          :errors
        else
          @apps = user_apps.order(:name).all
          :search
        end
      end

      r.post 'update_error', Error do |error|
        r.halt(403, view(:content=>"Error Not Open")) if error.closed
        error.closed = true if tp.bool('close')
        forme_set(error).save_changes
        flash['notice'] = "Error Updated"
        r.redirect("/error/#{error.id}")
      end

      r.post 'update_multiple_errors' do
        h = {:notes=>tp.str!('notes')}
        h[:closed] = true if tp.bool('close')
        n = Error.
          with_user(session['user_id']).
          where(:id=>tp.array!(:pos_int, 'ids'), :closed=>false).
          update(h)
        flash['notice'] = "Updated #{n} errors"
        r.redirect("/")
      end
    end
  end
end

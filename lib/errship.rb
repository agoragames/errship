require 'haml'

module Errship
  class Engine < Rails::Engine
    paths.app.routes = 'config/routes.rb'
    paths.app.views = 'app/views'

    # This method may have issues when an assets server is in use
    # (production) on pre-Rails3.1 applications.
    initializer 'errship_assets' do |app|
      app.middleware.insert_before ::ActionDispatch::Static, ::ActionDispatch::Static, "#{root}/public"
    end
  end

  module Rescuers
    def self.included(base)
      unless base.config.consider_all_requests_local
        base.rescue_from Exception, :with => :render_error
        base.rescue_from ActiveRecord::RecordNotFound, :with => :render_404_error
        base.rescue_from ActionController::RoutingError, :with => :render_404_error
        base.rescue_from ActionController::UnknownController, :with => :render_404_error
        base.rescue_from ActionController::UnknownAction, :with => :render_404_error
      end
    end
    
    def render_error(exception)
      HoptoadNotifier.notify(exception) if defined?(HoptoadNotifier)

      @page_title = 'Internal Server Error'
      render :template => '/errship/standard', :locals => { :status_code => 500 }
    end

    def render_404_error(exception = nil)
      
      # Workaround pre-Rails 3.1 for rescue_from RoutingError
      # A catchall route ends up here with params[:address] as the unknown route
      exception = ActionController::RoutingError.new(%(No route matches "/#{params[:address]}")) if params[:address]

      @page_title = 'Page Not Found'
      render :template => '/errship/standard', :locals => { :status_code => 404 }
    end
    
    # A blank page with just the layout and flash message, which can be redirected to when
    # all else fails.
    def errship_standard
      flash[:error] ||= 'An unknown error has occurred, or you have reached this page by mistake.'
      render :template => 'errship/standard', :locals => { :status_code => 500 }
    end

    # Set the error flash and attempt to redirect back. If RedirectBackError is raised,
    # redirect to error_path instead.
    def flashback(error_message)
      HoptoadNotifier.notify(exception)
      flash[:error] = 'An error occurred with our video provider. This issue has been reported - sorry about that!'
      begin
        redirect_to :back
      rescue ActionController::RedirectBackError
        redirect_to error_path
      end
    end

  end
end

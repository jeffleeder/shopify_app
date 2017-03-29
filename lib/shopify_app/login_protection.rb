module ShopifyApp
  module LoginProtection
    extend ActiveSupport::Concern

    included do
      rescue_from ActiveResource::UnauthorizedAccess, :with => :close_session
    end

    def shopify_session
      if shop_session
        begin
          ShopifyAPI::Base.activate_session(shop_session)
          yield
        ensure
          ShopifyAPI::Base.clear_session
        end
      else
        redirect_to_login
      end
    end

    def shop_session
      return unless session[:shopify]
      @shop_session ||= ShopifyApp::SessionRepository.retrieve(session[:shopify])
    end

    def login_again_if_different_shop
      if shop_session && params[:shop] && params[:shop].is_a?(String) && shop_session.url != params[:shop]
        session[:shopify] = nil
        session[:shopify_domain] = nil
        redirect_to_login
      end
    end

    protected

    def redirect_to_login
      if request.xhr?
        head :unauthorized
      else
        session[:return_to] = request.fullpath if request.get?
        redirect_to main_or_engine_login_url(shop: params[:shop])
      end
    end

    def close_session
      session[:shopify] = nil
      session[:shopify_domain] = nil
      redirect_to main_or_engine_login_url(shop: params[:shop])
    end

    def main_or_engine_login_url(params = {})
      main_app.login_url(params)
    rescue NoMethodError
      shopify_app.login_url(params)
    end

    def fullpage_redirect_to(url)
      if ShopifyApp.configuration.embedded_app?
        render inline: redirection_javascript(url)
      else
        redirect_to url
      end
    end

    def redirection_javascript(url)
      %(     
	    var loadScript = function(url, callback){

		var script = document.createElement('script')
		script.type = 'text/javascript';
	 
	    if (script.readyState){  //IE
	        script.onreadystatechange = function(){
	            if (script.readyState == 'loaded' ||
	                    script.readyState == 'complete'){
	                script.onreadystatechange = null;
	                callback();
	            }
	        };
	    } else {  //Others
	        script.onload = function(){
	            callback();
	        };
	    }
	 
	    script.src = url;
	    document.getElementsByTagName('head')[0].appendChild(script);
	};
	
			// if u need to order print out array, sort array use arry to fill out the jquery
			var myAppJavaScript = function($){
			// If the current window is the 'parent', change the URL by setting location.href
		  if (window.top == window.self) {
		    window.top.location.href = #{url.to_json};
		
		  // If the current window is the 'child', change the parent's URL with postMessage
		  } else {
		    normalizedLink = document.createElement('a');
		    normalizedLink.href = #{url.to_json};
		
		    data = JSON.stringify({
		      message: 'Shopify.API.remoteRedirect',
		      data: { location: normalizedLink.href }
		    });
		    window.parent.postMessage(data, "https://#{sanitized_shop_name}");
		  }
		
      
	};)
    end

    def sanitized_shop_name
      @sanitized_shop_name ||= sanitize_shop_param(params)
    end

    def sanitize_shop_param(params)
      return unless params[:shop].present?
      ShopifyApp::Utils.sanitize_shop_domain(params[:shop])
    end

  end
end

# Default backend definition.  Set this to point to your content server.
# all paths relative to varnish option vcl_dir

include "security/main.vcl";
include "custom.backend.vcl";
include "custom.acl.vcl";


# Handle the HTTP request received by the client 
sub vcl_recv {
    # shortcut for DFind requests
    if (req.url ~ "^/w00tw00t") {
        error 404 "Not Found";
    }

    if (req.restarts == 0) {
        if (req.http.X-Forwarded-For) {
            set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
        } else {
            set req.http.X-Forwarded-For = client.ip;
        }
    }

    # Normalize the header, remove the port (in case you're testing this on various TCP ports)
    set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");

    # Allow purging
    if (req.request == "PURGE") {
        if (!client.ip ~ purge) {
            # Not from an allowed IP? Then die with an error.
            error 405 "This IP is not allowed to send PURGE requests.";
        }

        # If you got this stage (and didn't error out above), do a cache-lookup
        # That will force entry into vcl_hit() or vcl_miss() below and purge the actual cache
        return (lookup);
    }

    # Only deal with "normal" types
    if (req.request != "GET" &&
            req.request != "HEAD" &&
            req.request != "PUT" &&
            req.request != "POST" &&
            req.request != "TRACE" &&
            req.request != "OPTIONS" &&
            req.request != "DELETE") {
        /* Non-RFC2616 or CONNECT which is weird. */
        return (pipe);
    }

    if (req.request != "GET" && req.request != "HEAD") {
        # We only deal with GET and HEAD by default
        return (pass);
    }

    # Some generic URL manipulation, useful for all templates that follow
    # First remove the Google Analytics added parameters, useless for our backend
    if (req.url ~ "(\?|&)(utm_source|utm_medium|utm_campaign|gclid|cx|ie|cof|siteurl)=") {
        set req.url = regsuball(req.url, "&(utm_source|utm_medium|utm_campaign|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "");
        set req.url = regsuball(req.url, "\?(utm_source|utm_medium|utm_campaign|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "?");
        set req.url = regsub(req.url, "\?&", "?");
        set req.url = regsub(req.url, "\?$", "");
    }

    # Strip hash, server doesn't need it.
    if (req.url ~ "\#") {
        set req.url = regsub(req.url, "\#.*$", "");
    }

    # Strip a trailing ? if it exists
    if (req.url ~ "\?$") {
        set req.url = regsub(req.url, "\?$", "");
    }

    # Some generic cookie manipulation, useful for all templates that follow
    # Remove the "has_js" cookie
    set req.http.Cookie = regsuball(req.http.Cookie, "has_js=[^;]+(; )?", "");

    # Remove any Google Analytics based cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmctr=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmcmd.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmccn.=[^;]+(; )?", "");

    # Remove the Quant Capital cookies (added by some plugin, all __qca)
    set req.http.Cookie = regsuball(req.http.Cookie, "__qc.=[^;]+(; )?", "");

    # Are there cookies left with only spaces or that are empty?
    if (req.http.cookie ~ "^ *$") {
        unset req.http.cookie;
    }

    # Normalize Accept-Encoding header
    # straight from the manual: https://www.varnish-cache.org/docs/3.0/tutorial/vary.html
    if (req.http.Accept-Encoding) {
        if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
            # No point in compressing these
            remove req.http.Accept-Encoding;
        } elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } elsif (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
        } else {
            # unkown algorithm
            remove req.http.Accept-Encoding;
        }
    }

    # Remove all cookies for static files
    # A valid discussion could be held on this line: do you really need to cache static files that don't cause load? Only if you have memory left.
    # Sure, there's disk I/O, but chances are your OS will already have these files in their buffers (thus memory).
    # Before you blindly enable this, have a read here: http://mattiasgeniar.be/2012/11/28/stop-caching-static-files/
    if (req.url ~ "^[^?]*\.(bmp|bz2|css|doc|eot|flv|gif|gz|ico|jpeg|jpg|js|less|mp[34]|pdf|png|rar|rtf|swf|tar|tgz|txt|wav|woff|xml|zip)(\?.*)?$") {
        unset req.http.Cookie;
        return (lookup);
    }

    # Send Surrogate-Capability headers to announce ESI support to backend
    set req.http.Surrogate-Capability = "key=ESI/1.0";

    # Include custom vcl_recv logic
    include "custom.recv.vcl";

    if (req.http.Authorization || req.http.Cookie) {
        # Not cacheable by default
        return (pass);
    }

    return (lookup);
}

sub vcl_pipe {
    # Note that only the first request to the backend will have
    # X-Forwarded-For set.  If you use X-Forwarded-For and want to
    # have it set for all requests, make sure to have:
    # set bereq.http.connection = "close";
    # here.  It is not set by default as it might break some broken web
    # applications, like IIS with NTLM authentication.

    #set bereq.http.Connection = "Close";
    return (pipe);
}

sub vcl_pass {
    return (pass);
}

# The data on which the hashing will take place
sub vcl_hash {
    hash_data(req.url);

    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }

    # hash cookies for object with auth
    if (req.http.Cookie) {
        hash_data(req.http.Cookie);
    }
    if (req.http.Authorization) {
        hash_data(req.http.Authorization);
    }

    # If the client supports compression, keep that in a different cache
    if (req.http.Accept-Encoding) {
        hash_data(req.http.Accept-Encoding);
    }

    return (hash);
}

sub vcl_hit {
    # Allow purges
    if (req.request == "PURGE") {
        purge;
        error 200 "purged";
    }

    return (deliver);
}

sub vcl_miss {
    # Allow purges
    if (req.request == "PURGE") {
        purge;
        error 200 "purged";
    }

    return (fetch);
}

# Handle the HTTP request coming from our backend 
sub vcl_fetch {
    # Include custom vcl_fetch logic
    include "custom.fetch.vcl";

    # Parse ESI request and remove Surrogate-Control header
    if (beresp.http.Surrogate-Control ~ "ESI/1.0") {
        unset beresp.http.Surrogate-Control;
        set beresp.do_esi = true;
    }

    # If the request to the backend returns a code is 5xx, restart the loop
    # If the number of restarts reaches the value of the parameter max_restarts,
    # the request will be error'ed.  max_restarts defaults to 4.  This prevents
    # an eternal loop in the event that, e.g., the object does not exist at all.
    if (beresp.status >= 500 && beresp.status <= 599){
        return(restart);
    }

    # Enable cache for all static files
    # The same argument as the static caches from above: monitor your cache size, if you get data nuked out of it, consider giving up the static file cache.
    # Before you blindly enable this, have a read here: http://mattiasgeniar.be/2012/11/28/stop-caching-static-files/
    if (req.url ~ "^[^?]*\.(bmp|bz2|css|doc|eot|flv|gif|gz|ico|jpeg|jpg|js|less|mp[34]|pdf|png|rar|rtf|swf|tar|tgz|txt|wav|woff|xml|zip)(\?.*)?$") {
        unset beresp.http.set-cookie;
    }

    # Set 2min cache if unset for static files
    if (beresp.ttl <= 0s || beresp.http.Set-Cookie || beresp.http.Vary == "*") {
        set beresp.ttl = 120s;
        return (hit_for_pass);
    }

    return (deliver);
}

# The routine when we deliver the HTTP request to the user
# Last chance to modify headers that are sent to the client
sub vcl_deliver {
    
    if (!req.http.Pragma ~ "X-Cacheable") {
      unset resp.http.X-Cacheable;
    }
    if (req.http.Pragma ~ "X-Age") {
      set resp.http.X-Age = resp.http.Age;
    }
    unset resp.http.X-Cache-Server;
    unset resp.http.X-Cache;
    unset resp.http.X-Cache-Hits;
  
    if (req.http.Pragma ~ "X-Cache-Server") {
      # debugging only, remove in prod
      set resp.http.X-Cache-Server = server.hostname;
    }
    if (obj.hits > 0) {
            if (req.http.Pragma ~ "X-Cache") {
              set resp.http.X-Cache = "HIT";
            }
            if (req.http.Pragma ~ "X-Cache-Hits") {
              set resp.http.X-Cache-Hits = obj.hits;
            }
    } else {
            if (req.http.Pragma ~ "X-Cache") {
              set resp.http.X-Cache = "MISS";
            }
    }

    # Remove some headers: PHP version
    unset resp.http.X-Powered-By;

    # Remove some headers: Apache version & OS
    unset resp.http.Server;
    unset resp.http.Age;
    unset resp.http.X-Drupal-Cache;
    unset resp.http.X-Varnish;
    unset resp.http.Via;
    unset resp.http.Link;

    return (deliver);
}

sub vcl_error {
    if (obj.status >= 500 && obj.status <= 599 && req.restarts < 4) {
        # 4 retry for 5xx error
        return(restart);
    } elsif (obj.status >= 400 && obj.status <= 499 ) {
        # use 404 error page for 4xx error
        include "conf.d/error-404.vcl";
    } elsif (obj.status <= 200 && obj.status >= 299 ) {
        # for other errors (not 5xx, not 4xx and not 2xx)
        include "conf.d/error.vcl";
    } else {
        include "conf.d/error.vcl";
    }
    return (deliver);
}

sub vcl_init {
    return (ok);
}

sub vcl_fini {
    return (ok);
}

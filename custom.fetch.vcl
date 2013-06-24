# stream big file, add missing extention below
if (req.url ~ "\.(avi|deb|tar|gz|rar|iso|img|dmg|mkv|zip)$") {
    set beresp.do_stream = true;
    set beresp.ttl = 1d;
}

# Allow items to be stale if needed.
   if (beresp.status == 500) { 
      set beresp.saintmode = 20s;
      if (req.request != "POST") {
           return(restart);
      } else {
           error 500 "Failed";
      }
   }
   set beresp.grace = 1h;

include "conf.d/fetch/default.vcl";

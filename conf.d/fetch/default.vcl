## Drop any cookies being sent back to the client.
#if (!(req.url ~ "wp-(login|admin)")) {
#    unset beresp.http.set-cookie;
#}

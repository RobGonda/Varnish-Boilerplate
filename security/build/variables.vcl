/* Autogenerated with ../tools/generate_variables at  Fri Sep  7 14:27:47 UTC 2012 
 *
 * Do not modify, modify VARIABLES and rerun ../tools/generate_variables instead.
 */

sub vcl_recv
{
	unset req.http.X-SEC-Severity;
	unset req.http.X-SEC-Return;
	unset req.http.X-SEC-Arg;
	unset req.http.X-SEC-Module;
	unset req.http.X-SEC-RuleId;
	unset req.http.X-SEC-Rule;
	unset req.http.X-SEC-RuleName;
	unset req.http.X-SEC-RuleInfo;
	unset req.http.X-SEC-Client;
	unset req.http.X-SEC-Response;
	unset req.http.X-SEC-Cloak-status;
}
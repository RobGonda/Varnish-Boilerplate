/* Security.vcl config VCL file
 * Copyright (C) 2009 Redpill Linpro AS
 * Copyright (C) 2009 Kristian Lyngstøl
 * Copyright (C) 2009 Kacper Wysocki
 * Copyright (C) 2009 Edward Bjarte Fjellskål
 *
 * In this file you specify which rulesets to configure.
 *
 */

# Comment out any include line to disable the security module.
include "modules/demo.vcl";
include "modules/php.vcl";
include "modules/sql.vcl";
include "modules/xss.vcl";
#include "modules/cmd.vcl"; # wget rule kinda sucks for repo
include "modules/restricted-file-extensions.vcl";
include "modules/content-encoding.vcl";
include "modules/content-type.vcl";
include "modules/localfiles.vcl";

# check this module, it is rather harsh
include "modules/request.vcl";

# you may or may not want these
# include "modules/robots.vcl";
include "modules/cloak.vcl";

## User agent checks may be a little too restrictive for your tastes.
#include "modules/user-agent.vcl";

## The breach2vcl tool is not perfect...
# include "breach.vcl";


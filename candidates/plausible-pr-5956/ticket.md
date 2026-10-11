# Dedicated tracker scripts fail in Community Edition until restart

On a self-hosted Community Edition instance, dedicated tracker scripts for newly configured sites can return server errors. Existing scripts may continue to work, and restarting the application temporarily makes the affected script available again.

Exercise this without restarting: create a site's dedicated script configuration, request its script, change a setting such as file-download tracking, then request it again. Repeat the configuration change and keep another site's script available throughout.

Each successful configuration update should leave the dedicated script endpoint serving one valid script for the correct site with its current settings. It must not return a server error, stale settings or another site's script. Newly created configurations and repeated updates must both work, while other sites remain unaffected.

Fix the CE behavior and add regression coverage through the configuration and script-serving paths. There is no response-time requirement.

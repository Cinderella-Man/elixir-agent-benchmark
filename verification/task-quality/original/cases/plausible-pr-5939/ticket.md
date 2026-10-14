# Editors cannot change a site's domain

A user invited to a site as an Editor cannot use its Change domain page. A team member with the Editor role encounters the same problem, although editors are meant to manage this setting for sites they can edit.

Reproduce this with a site named old.example.com, first as its guest Editor and then as an Editor in its owning team. Open the Change domain page and submit new.example.com.

Both editors should be able to complete the change. The persisted site should have the new domain and retain old.example.com as its previous domain, as it already does for a successful owner change. Team Admins and Owners must continue to work. Viewers and people without access to the site must remain unable to change it.

Fix the permission regression and add coverage for these role boundaries.

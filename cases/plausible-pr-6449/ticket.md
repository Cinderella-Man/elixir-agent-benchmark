# Shared-link edits can change the URL token or attach another site's segment

The shared-link settings form accepts submitted values that should not be able to change the link's identity or associate it with another site's data.

Create a shared link for site A, then edit it with an extra slug field containing a different token. Also try submitting the ID of a segment belonging to site B when creating or editing a link for site A.

Expected behavior:

- Editing a link must preserve its original secret URL token, even if a different slug is submitted.
- A segment may be attached only when it belongs to the link's site. Invalid, nonexistent or foreign-site selections should save with no segment attached.
- A valid same-site selection must still attach, and an empty selection must clear the association.
- Renaming a link must retain its submitted same-site segment even if that segment was changed from site-wide to personal after the link was created.

Repair these boundaries through the real create/edit flow, keep ordinary editing and permission checks working, and add regression coverage.

An invalid segment submitted while editing an already-associated link must clear the old association, just as it does when creating a new link.

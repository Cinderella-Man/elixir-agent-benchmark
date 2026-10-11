# Adding S3 storage through the workspace form fails

Adding S3 storage from the personal workspace settings does not work even when the connection settings are valid.

Open the workspace settings, choose to add S3 storage, and submit the bucket URL, region, access key and secret key shown in the form. With a successful S3 connection, the storage should be saved for that workspace and appear in its storage list. Users should only need to submit the fields displayed by the form. Existing storage editing and validation should continue to work.

Fix the form workflow and add a LiveView regression test that submits the same fields a user submits. Tests can use the existing local S3 stub; no real cloud credentials are needed.

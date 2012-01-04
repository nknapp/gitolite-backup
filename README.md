Gitolite Backup
===============

This project is intended to be a backup script for the gitolite hosting system.

At the moment, there is an "install.sh" script that can be used to setup the backup in the same location as the cloned repository

The "backup.sh" script builds a mirror of the whole gitolite home-directory without the repositories using "rsync". It then uses a "backup" user to mirror all repositories that this user can read. You can configure, which repositories should be backed up by setting appropriate read permissions for this user.

Using "git --mirror" to copy the repositories should also avoid inconsistencies when the backup is running during a push.

The idea is, that the whole thing is mirrorerd somewhere, where a real backup tool can read it.

**I give no warranty that using this script won't destroy your installation. I do not guarantee for neither script**


TODO
----

* Restore process for single repositories
* More intelligent backup process (every repository already has the whole history, so we do not need to keep multiple instances of the backup, only the refs are needed in multiple instances).
* Copy the result somewhere safe. This is not done yet.

Everything is still work in progress.



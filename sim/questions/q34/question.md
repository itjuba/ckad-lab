# Fix a suspended CronJob

Namespace: `scutum`

Team Scutum's backup never runs. The CronJob `scutum-backup` was paused during an incident
and left with a test schedule.

1. Change the schedule of CronJob `scutum-backup` to every 6 hours at minute 0
   (`0 */6 * * *`).

2. Make the schedule use the time zone `Europe/Paris`.

3. Resume the CronJob so it runs on its schedule again.

4. Keep only **1** successful and **1** failed Job in its history.

5. Don't wait 6 hours to test it: create a Job named `scutum-backup-now` from the CronJob,
   let it finish, and write its logs to `/opt/course/34/backup.log`.

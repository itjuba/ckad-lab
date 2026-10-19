# CronJob with history limits and a manual run

Namespace: `rigel`

Team Rigel generates a usage report every quarter of an hour.

1. Create a CronJob named `rigel-report` in Namespace `rigel`:
   - it runs every 15 minutes
   - image `busybox:1.37`, command `sh -c 'date; echo report generated'`
   - a new run must not start while the previous run is still active
   - keep the last **2** successful Jobs and the last **1** failed Job
   - a run that can't start within **60 seconds** of its scheduled time is skipped
   - a failed container is restarted in the same Pod (not in a new Pod)

2. Don't wait for the schedule. Create a Job named `rigel-report-manual` from
   the CronJob so the report runs right now.

3. Write the logs of `rigel-report-manual` into `/opt/course/19/manual.log`.

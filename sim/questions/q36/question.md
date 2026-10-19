# Two containers sharing a volume

Namespace: `musca`

Team Musca's app writes a log file that a second process must read while it's being written.

1. Create a Pod `musca-pair` in Namespace `musca` with an emptyDir volume named `shared`,
   mounted at `/shared` in both of these containers:
   - `producer` (image `busybox:1.37`) appends the output of `date` to `/shared/out.log`
     every 3 seconds
   - `consumer` (image `busybox:1.37`) runs `tail -F /shared/out.log`

2. Write the logs of the `consumer` container to `/opt/course/36/consumer.log`.

3. Run `ls /shared` in the `consumer` container and write its output to
   `/opt/course/36/shared-ls`.

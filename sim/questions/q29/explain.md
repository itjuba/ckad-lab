# Lesson 29: Pod command, args and environment variables

Curriculum: "Define, build and modify container images" and the basics of Pods behind
every other topic (Application Design and Build, 20%).

------------------------------------------------------------------------------------------
## 1. What runs inside a container

Every image has a default program. In a Dockerfile it's set by:

  ENTRYPOINT   the executable                 e.g. ["nginx"]
  CMD          its default arguments          e.g. ["-g", "daemon off;"]

A Pod can override both:

  Kubernetes field   overrides            meaning
  command            ENTRYPOINT           which program to run
  args               CMD                  the arguments passed to it

If you set neither, the image's defaults run. If you set only `args`, the image's
ENTRYPOINT runs with your arguments. If you set `command`, the image's ENTRYPOINT is
ignored.

------------------------------------------------------------------------------------------
## 2. Running a shell script in a container

busybox and alpine images have a shell, `sh`. `sh -c '<script>'` runs a one-line script.
A common pattern splits the shell and the script:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demo
  labels:
    app: demo                       # labels go under metadata
spec:
  containers:
  - name: demo                      # container name (kubectl run uses the Pod name)
    image: busybox:1.37
    command: ["sh", "-c"]           # the program: a shell
    args: ["echo hello; sleep 3600"] # its argument: the script, as ONE string
```

Why `sleep 3600`? A container lives only as long as its main process. A script that just
echoes and exits would end, and the Pod would restart it over and over.

------------------------------------------------------------------------------------------
## 3. Environment variables

```yaml
    env:
    - name: GREETING                # variable name
      value: "hello"                # always a string
    - name: COUNT
      value: "3"                    # numbers must be quoted too
```

Inside the container, the shell reads them as `$GREETING`. Environment variables can also
come from ConfigMaps and Secrets (see lessons 15, 37, 14, 38).

------------------------------------------------------------------------------------------
## 4. Generating it with kubectl run

`kubectl run` creates a Pod and can set most of this:

```bash
k run demo -n ns --image=busybox:1.37 -l app=demo --env=GREETING=hello \
  $do -- sh -c 'echo hello; sleep 3600'
```

  -l app=demo          labels (comma-separated for several: -l a=1,b=2)
  --env=NAME=value     one --env per variable

Everything after `--` becomes the container's arguments:

  -- sh -c '...'             -> args: ["sh", "-c", "..."]       (no command)
  --command -- sh -c '...'   -> command: ["sh", "-c", "..."]    (no args)

To get the exact split a task asks for (shell in `command`, script in `args`), generate
the YAML with $do and move the parts in vim.

Quoting: wrap the script in single quotes on the command line, so YOUR shell doesn't
replace `$GREETING` with an empty value before kubectl even sees it.

Check the result:

```bash
k get pod demo -n ns -o yaml | grep -A3 -e command -e args
k explain pod.spec.containers.command
```

------------------------------------------------------------------------------------------
## 5. Logs and exec: seeing what the container does

```bash
k logs demo -n ns                         # everything the main process printed
k exec demo -n ns -- printenv GREETING    # run one command inside the container
k exec demo -n ns -- env                  # all its environment variables
k exec -it demo -n ns -- sh               # interactive shell (exit to leave)
```

`--` separates kubectl's options from the command to run in the container. Both commands
print to your terminal, so `> file` saves the output.

------------------------------------------------------------------------------------------
## 6. How this applies to question 29

  Task 1  Generate the Pod with `k run` (name, image, label, both env vars) and $do.
          In vim, rename the container if needed, and arrange it so `command` holds only
          the shell and `args` holds the script. Apply and wait for Running.
  Task 2  The Pod's logs into the file.
  Task 3  `k exec` the given command and redirect its output into the file.

------------------------------------------------------------------------------------------
## 7. Common mistakes

  - The whole thing in `command` (or all in `args`) when the task asks for the split
  - Script split into several array items: `args` needs it as ONE string after `-c`
  - Double quotes around the script on the command line: your shell expands `$GREETING`
    to nothing, and the Pod prints ", "
  - Forgetting `sleep`: the container exits and keeps restarting
  - Unquoted numbers in `env.value`: the API rejects non-strings

------------------------------------------------------------------------------------------
## 8. Docs (kubernetes.io)

  Search "Define a Command and Arguments for a Container"   command vs args, examples
  Search "Define Environment Variables for a Container"      env examples
  Search "kubectl run"                                       flags reference

See also: ckad explain 2 (Pod basics), ckad explain 30 (logs and exec)

Now try it: ckad q 29

# Devfiles for PairSpaces

Use PairSpaces and work together with your team using Devfiles (see https://devfile.io).

## Usage

In your `devfile.yaml`:

```yaml
schemaVersion: 2.2.0
metadata:
  name: pairspaces-dev

components:
  - name: devenv
    container:
      image: node:18
      mountSources: true
      command: ["sleep"]
      args: ["infinity"]

commands:
  - id: install-pair
    exec:
      component: devenv
      commandLine: curl -fsSL https://raw.githubusercontent.com/pairspaces/devfiles/main/install.sh?a=b | bash
      group:
        kind: run

  - id: start-supervisord
    exec:
      component: devenv
      commandLine: supervisord -c /etc/supervisor/supervisord.conf
      group:
        kind: run

  - id: bootstrap
    exec:
      component: devenv
      commandLine: |
        while [ ! -x /opt/pair/pair ]; do sleep 1; done
        /opt/pair/pair spaces bootstrap "[OUTPUT from `pair spaces authorize` HERE]"
      workingDir: /projects
      group:
        kind: run
        isDefault: true

events:
  postStart:
    - install-pair
    - start-supervisord
    - bootstrap
```


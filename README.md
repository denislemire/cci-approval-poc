# cancel-approvals.sh

Script to use CircleCI's API to look for and cancel long running approval jobs.

## How-to

Set CIRCLE_TOKEN environment variable, example:

```bash
export CIRCLE_TOKEN=`op item get vdhoqk4qqmqyxm274lsajqhw2y --fields token`
```

### Usage

```bash
./cancel-approvals.sh slug [hours]
```

Format of slug is `<vcs_type>/<org_name>`, eg) gh/denislemire

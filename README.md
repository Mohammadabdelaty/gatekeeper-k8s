# Policy Operator

We need to make a policy for developpers to only allow usage of local harbor (docker regitery). Also to guide them to run containers as themselves with their UID & GID not as root 

We need to let the users have the rules and procedures so they know how to run their workloads without any warnings. to do that we need to rewrite the same policy with 2 differents ways:
1- *Admin policy*: which will be used to deploythe rpolicy itself. 
2- *User policy*: to test their work befor deploying.

create rego policy for local docker `policy/user.rego`.

Now let's share the above `user.rego` file with user to test them on their manifist files using `conftest` commmand, to install it follow these steps:

```bash
LATEST_VERSION=$(wget -O - "https://api.github.com/repos/open-policy-agent/conftest/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c 2-)
ARCH=$(arch)
SYSTEM=$(uname)
wget "https://github.com/open-policy-agent/conftest/releases/download/v${LATEST_VERSION}/conftest_${LATEST_VERSION}_${SYSTEM}_${ARCH}.tar.gz"
tar xzf conftest_${LATEST_VERSION}_${SYSTEM}_${ARCH}.tar.gz
sudo mv conftest /usr/local/bin
```

Now test your job

```bash
# Test the good job first
conftest test -p user.rego goodjob.yaml 

5 tests, 5 passed, 0 warnings, 0 failures, 0 exceptions


# The bad job
conftest test -p user.rego badjob.yaml 
FAIL - badjob.yaml - main - Container "test" uses disallowed image: "alpine"
FAIL - badjob.yaml - main - Container must set runAsGroup
FAIL - badjob.yaml - main - Container must set runAsUser
FAIL - badjob.yaml - main - Job must not run as root
FAIL - badjob.yaml - main - Pod must set fsGroup

5 tests, 0 passed, 0 warnings, 5 failures, 0 exceptions
```

But before we create the policy we need to create an admin version of the policy -as we said above- so we do some changes to the `user.rego` file, so let's copy the `user.rego` dir to `admin.rego`.

```bash
cp user.rego admin.rego
```

Then only two change to be done manully:

1- replace `main` with `k8spolicy`

2- replace `deny[msg]` with `violation[{"msg": msg, "details":{}}]`

3- replace `input.kind` with `input.review.kind.kind`

4- replace `input.spec` with `input.review.object.spec`

## Applying the constraint

We need to install `Gatekeeper`

Gatekeeper allows a Kubernetes administrator to implement policies for ensuring compliance and best practices in their cluster.

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
helm install -n gatekeeper-system gatekeeper gatekeeper/gatekeeper --create-namespace
```

Wait for all the pods to be in `Running` status.

Now back to our policies, to apply the above policies, we use `konstraint` command with the following installtion steps:

```bash
wget https://github.com/plexsystems/konstraint/releases/download/v0.41.0/konstraint_Linux_x86_64.tar.gz
tar -xzf konstraint_Linux_x86_64.tar.gz
sudo mv konstraint /usr/local/bin/
```

Create constraint and template in `policy` dir.

```bash
konstraint create -o policy admin.rego
```

You may need to rename the yaml file (Optional):

`template_..yaml` to `template_test.yaml`
`constraint_..yaml` to `constraint_test.yaml`

First thing after renaming is to edit the manefist of the template with `name` and `crd.spec.names.kind` as it will create the `crd` which will be the constraint itself, confused?, let's see it together.

Edit the template as follows to create the `Test` crd:

```yaml
  name: test
spec:
  crd:
    spec:
      names:
        kind: Test
```

```bash
kubectl apply -f policy/template_test.yaml -n test
```

Now checkout the create `crds` in the test `ns`.

In my case I need to only specify kind `Job` in the `constraint_test.yaml` file as my targeted workload, and to specific `ns` with a specific label add the following:

So, apply to labeled ns with `label: gatekeeper`.

```bash
kubectl label ns test label=gatekeeper
```

Then rewrite the constraint_test.yaml as follows:

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: Test
metadata:
  name: test
spec:
  match:
    kinds:
      - apiGroups: ["batch"]
        kinds: ["Job"]
    namespaceSelector:
      matchLabels:
        label: gatekeeper
```

Apply the constraint

```bash
kubectl apply -f policy/constraint_test.yaml -n test 
```

Then test the jobs
```bash
# The bad job
kubectl apply -f badjob.yaml -n test
Error from server (Forbidden): error when creating "badjob.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [test] Container "test" uses disallowed image: "alpine"
[test] Container must set runAsGroup
[test] Container must set runAsUser
[test] Job must not run as root
[test] Pod must set fsGroup

#The good job
kubectl apply -f goodjob.yaml -n test
job.batch/job created
```
Finally you can control most of the args in the manifist file, just follow the logic and the references.

## References:
1- [Gatekeeper](https://github.com/open-policy-agent/gatekeeper)

2- [Konstraint](https://github.com/plexsystems/konstraint)

3- [Conftest](https://www.conftest.dev/install/)

4- [Policy Operator](https://learnk8s.io/kubernetes-policies)

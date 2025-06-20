# CI setup

Jetlag uses the [OpenShift CI Robot](https://github.com/openshift-ci-robot) to implement its CI.

See this [example PR](https://github.com/redhat-performance/jetlag/pull/567) to understand how to interact with the CI system.

There are currently 6 possible tests:
 - deploy-5nodes: Deploys a 5 node, 2 worker MNO cluster on the latest stable release
 - deploy-5nodes-dev: Deploys a 5 node, 2 worker MNO cluster on the latest development release
 - deploy-compact: Deploys a 3 node compact MNO cluster on the latest stable release
 - deploy-compact-dev: Deploys a 3 node compact MNO cluster on the latest development release
 - deploy-sno: Deploys a SNO cluster on the latest stable release
 - deploy-sno-dev: Deploys a SNO cluster on the latest development release

Only verified users of the [OpenShift github organization](https://github.com/openshift) are allowed to trigger the tests.

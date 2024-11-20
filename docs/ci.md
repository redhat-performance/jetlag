# CI setup

Jetlag uses the [OpenShift CI Robot](https://github.com/openshift-ci-robot) to implement its CI.

See this [example PR](https://github.com/redhat-performance/jetlag/pull/567) to understand how to interact with the CI system.

There are currently 4 possible tests:
 - deploy-5nodes: Deploys a 2 worker MNO OCP cluster on the latest stable release
 - deploy-5nodes-dev: Deploys a 2 worker MNO OCP cluster on the latest development release
 - deploy-sno: Deploys a SNO OCP cluster on the latest stable release
 - deploy-sno-dev: Deploys a SNO OCP cluster on the latest development release

Only verified users of the [OpenShift github organization](https://github.com/openshift) are allowed to trigger the tests.

For troubeshooting purposes, access the [Jetlag:CI cluster](https://wiki.rdu3.labs.perfscale.redhat.com/#cloud19) on the [performance lab](https://wiki.rdu3.labs.perfscale.redhat.com/).